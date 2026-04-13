import * as functions from "firebase-functions/v2";
import * as functionsV1 from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { getFirestore, initializeFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import * as gcpMetadata from "gcp-metadata";
import { randomUUID } from "crypto";

const appOptions: admin.AppOptions = {};
const firebaseConfig = process.env.FIREBASE_CONFIG?.startsWith("{")
    ? JSON.parse(process.env.FIREBASE_CONFIG) as { projectId?: string; databaseURL?: string }
    : undefined;

if (process.env.FIRESTORE_EMULATOR_HOST && !process.env.FIRESTORE_PREFER_REST) {
    process.env.FIRESTORE_PREFER_REST = "true";
}

if (process.env.FIRESTORE_EMULATOR_HOST) {
    (gcpMetadata as { universe?: unknown }).universe =
        (async () => "googleapis.com") as unknown;
}

const projectId = process.env.GCLOUD_PROJECT
    || process.env.GOOGLE_CLOUD_PROJECT
    || firebaseConfig?.projectId;

if (projectId) {
    appOptions.projectId = projectId;
}

if (process.env.FIREBASE_DATABASE_URL) {
    appOptions.databaseURL = process.env.FIREBASE_DATABASE_URL;
} else if (firebaseConfig?.databaseURL) {
    appOptions.databaseURL = firebaseConfig.databaseURL;
}

admin.initializeApp(appOptions);
const firestore = process.env.FIRESTORE_EMULATOR_HOST
    ? initializeFirestore(admin.app(), { preferRest: true })
    : getFirestore(admin.app());

const FUNCTIONS_REGION = process.env.FUNCTIONS_REGION || "europe-west1";

interface Haptic {
    timestamp: admin.firestore.Timestamp;
    senderId: string;
    type: HapticType
}

type HapticType = DefaultInfo | EmojiInfo | EmptyInfo | SketchInfo;

interface DefaultInfo {
    type: string;
}

interface EmojiInfo {
    type: string;
    emoji: string;
}

interface EmptyInfo {
    type: string;
}

interface SketchInfo {
    type: string;
    color: string;
}

interface Conversation {
    id: string;
    peers: string[];
    timestamp: Date | admin.firestore.Timestamp;
}

interface UserTokensInfo {
    tokens: Array<{ token: string }>;
}

interface Profile {
    name: string;
}

const hapticNotificationBarierInSeconds = 5;
const ayoNotificationBarrierInSeconds = 60;
const sendRequestBarrierInSeconds = 15;
const updateInvitesBarrierInSeconds = 60;
const appleReferenceDateOffsetInSeconds = 978307200;

const notificationCategoryNewMessage = "newMessage";

const notificationCategoryFriendRequest = "friendRequest";

const notificationCategoryAyo = "ayo";

function toStringArray(value: unknown): string[] {
    if (Array.isArray(value)) {
        return value.filter((entry): entry is string => typeof entry === "string");
    }

    if (value && typeof value === "object") {
        return Object.values(value).filter((entry): entry is string => typeof entry === "string");
    }

    return [];
}

function toStringArrayMap(value: unknown): Record<string, string[]> {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
        return {};
    }

    const map: Record<string, string[]> = {};
    Object.entries(value as Record<string, unknown>).forEach(([key, nestedValue]) => {
        map[key] = toStringArray(nestedValue);
    });

    return map;
}

function sharedConversationExists(
    conversations: Record<string, string[]>,
    userId: string,
    peerId: string
): boolean {
    const userConversationIds = new Set(toStringArray(conversations[userId]));
    return toStringArray(conversations[peerId]).some((conversationId) => userConversationIds.has(conversationId));
}

function addConversationToUserConversations(
    conversations: Record<string, string[]>,
    conversationId: string,
    userId: string
): boolean {
    const conversationsForUserId = toStringArray(conversations[userId]);

    if (conversationsForUserId.includes(conversationId)) {
        return false;
    }

    conversations[userId] = [...conversationsForUserId, conversationId];
    return true;
}

function removeConversationFromUserConversations(
    conversations: Record<string, string[]>,
    conversationId: string,
    userId: string
): void {
    if (!conversations[userId]) {
        return;
    }

    conversations[userId] = conversations[userId].filter((existingConversationId) => existingConversationId !== conversationId);
}

async function checkUsersForBlock(userId: string, peerId: string): Promise<void> {
    const [userBlocksSnapshot, peerBlocksSnapshot] = await Promise.all([
        admin.database().ref(`userBlocks/${userId}/${peerId}`).get(),
        admin.database().ref(`userBlocks/${peerId}/${userId}`).get()
    ]);

    if (userBlocksSnapshot.exists() || peerBlocksSnapshot.exists()) {
        throw new HttpsError("failed-precondition", "User is blocked.");
    }
}

async function acquireThrottle(path: string, barrierInSeconds: number, message: string): Promise<void> {
    const nowInSeconds = Math.floor(Date.now() / 1000);
    const result = await admin.database()
        .ref(path)
        .transaction((lastTimestamp: number | null) => {
            if (typeof lastTimestamp === "number" && nowInSeconds - lastTimestamp < barrierInSeconds) {
                return;
            }

            return nowInSeconds;
        });

    if (!result.committed) {
        throw new HttpsError("resource-exhausted", message);
    }
}

async function userExists(userId: string): Promise<boolean> {
    const userDoc = await firestore.collection("users").doc(userId).get();
    return userDoc.exists;
}

function createEmptyHaptic(senderId: string) {
    return {
        id: randomUUID(),
        senderId,
        timestamp: (Date.now() / 1000) - appleReferenceDateOffsetInSeconds,
        type: {
            type: "empty",
            fromRect: [[0, 0], [0, 0]],
            location: [0, 0]
        }
    };
}

function buildConversationIndex(conversationIds: string[]): Record<string, true> | null {
    const uniqueConversationIds = Array.from(new Set(conversationIds));

    if (uniqueConversationIds.length === 0) {
        return null;
    }

    return uniqueConversationIds.reduce<Record<string, true>>((index, conversationId) => {
        index[conversationId] = true;
        return index;
    }, {});
}

function isFiniteNumber(value: unknown): value is number {
    return typeof value === "number" && Number.isFinite(value);
}

function isPoint(value: unknown): value is [number, number] {
    return Array.isArray(value)
        && value.length === 2
        && isFiniteNumber(value[0])
        && isFiniteNumber(value[1]);
}

function isRect(value: unknown): value is [[number, number], [number, number]] {
    return Array.isArray(value)
        && value.length === 2
        && isPoint(value[0])
        && isPoint(value[1]);
}

function isPointArray(value: unknown): value is Array<[number, number]> {
    return Array.isArray(value) && value.every((point) => isPoint(point));
}

function validateHapticPayload(value: unknown, senderId: string): asserts value is Record<string, unknown> {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
        throw new HttpsError("invalid-argument", "Haptic payload must be an object.");
    }

    const haptic = value as Record<string, unknown>;
    if (typeof haptic.id !== "string" || haptic.id.length === 0) {
        throw new HttpsError("invalid-argument", "Haptic id is required.");
    }

    if (!isFiniteNumber(haptic.timestamp)) {
        throw new HttpsError("invalid-argument", "Haptic timestamp is required.");
    }

    if (haptic.senderId !== senderId) {
        throw new HttpsError("permission-denied", "Cannot send a haptic for another user.");
    }

    if (!haptic.type || typeof haptic.type !== "object" || Array.isArray(haptic.type)) {
        throw new HttpsError("invalid-argument", "Haptic type is required.");
    }

    const type = haptic.type as Record<string, unknown>;
    switch (type.type) {
        case "default":
        case "empty":
            if (!isRect(type.fromRect) || !isPoint(type.location)) {
                throw new HttpsError("invalid-argument", "Invalid haptic geometry.");
            }
            return;
        case "emoji":
            if (!isRect(type.fromRect) || !isPoint(type.location) || typeof type.emoji !== "string" || type.emoji.length === 0) {
                throw new HttpsError("invalid-argument", "Invalid emoji haptic payload.");
            }
            return;
        case "sketch":
            if (
                !isRect(type.fromRect)
                || !isPointArray(type.locations)
                || typeof type.color !== "string"
                || !isFiniteNumber(type.lineWidth)
            ) {
                throw new HttpsError("invalid-argument", "Invalid sketch haptic payload.");
            }
            return;
        default:
            throw new HttpsError("invalid-argument", "Unsupported haptic type.");
    }
}

function convertToHaptic(data: any): Haptic | undefined {
    if (data.timestamp) {
        const seconds = Math.floor(data.timestamp);
        const nanoseconds = Math.floor((data.timestamp - seconds) * 1e9);

        const timestamp = new admin.firestore.Timestamp(seconds, nanoseconds);

        let type: HapticType;
        switch (data.type.type) {
            case "default":
                type = { type: "default" };
                break;
            case "emoji":
                type = { type: "emoji", emoji: data.type.emoji as string };
                break;
            case "sketch":
                type = { type: "sketch", color: data.type.color as string };
                break;
            case "empty":
                type = { type: "empty" };
                break;
            default:
                return undefined;
        }

        return {
            timestamp: timestamp,
            senderId: data.senderId,
            type: type
        };
    } else {
        return undefined;
    }
}

async function sendNotificationToUser(
    userId: string,
    message: Omit<admin.messaging.MulticastMessage, 'tokens'>
): Promise<void> {
    const tokensRef = firestore.collection('pushTokens').doc(userId);
    const tokensDoc = await tokensRef.get();

    if (!tokensDoc.exists) {
        functions.logger.error(`Push tokens for user with id: ${userId}, do not exist`);
        return;
    }

    const userTokensInfo = tokensDoc.data() as UserTokensInfo | undefined;

    if (!userTokensInfo || !userTokensInfo.tokens || userTokensInfo.tokens.length === 0) {
        functions.logger.error(`No push tokens found for user id: ${userId}`);
        return;
    }

    const tokens = userTokensInfo.tokens.map(userTokenInfo => userTokenInfo.token);

    const fullMessage: admin.messaging.MulticastMessage = {
        ...message,
        tokens: tokens
    };

    const response = await admin.messaging().sendEachForMulticast(fullMessage);

    // Clean up stale tokens
    const tokensToRemove: string[] = [];
    response.responses.forEach((result, index) => {
        if (result.error) {
            const errorCode = result.error.code;
            if (errorCode === 'messaging/invalid-registration-token' ||
                errorCode === 'messaging/registration-token-not-registered') {
                tokensToRemove.push(tokens[index]);
            }
        }
    });

    if (tokensToRemove.length > 0) {
        const remainingTokens = userTokensInfo.tokens.filter(
            tokenInfo => !tokensToRemove.includes(tokenInfo.token)
        );
        await tokensRef.set({ tokens: remainingTokens });
        functions.logger.log(`Removed ${tokensToRemove.length} stale tokens for user ${userId}`);
    }
}

async function cleanupDeletedUserData(userId: string): Promise<void> {
    const database = admin.database();
    const rootRef = database.ref();

    const [
        userConversationsSnapshot,
        requestsSnapshot,
        invitesSnapshot,
        userBlocksSnapshot,
        conversationsSnapshot,
        reportsSnapshot
    ] = await Promise.all([
        database.ref("userConversations").get(),
        database.ref("requests").get(),
        database.ref("invites").get(),
        database.ref("userBlocks").get(),
        firestore.collection("conversations").where("peers", "array-contains", userId).get(),
        firestore.collection("reports").get()
    ]);

    const userConversations = toStringArrayMap(userConversationsSnapshot.val());
    const requests = toStringArrayMap(requestsSnapshot.val());
    const updates: Record<string, unknown> = {
        [`requests/${userId}`]: null,
        [`invites/${userId}`]: null,
        [`userBlocks/${userId}`]: null,
        [`userConversations/${userId}`]: null,
        [`userConversationsIndex/${userId}`]: null
    };

    Object.entries(requests).forEach(([otherUserId, requestUserIds]) => {
        if (otherUserId === userId) {
            return;
        }

        const filteredRequestUserIds = requestUserIds.filter((requestUserId) => requestUserId !== userId);
        if (filteredRequestUserIds.length !== requestUserIds.length) {
            updates[`requests/${otherUserId}`] = filteredRequestUserIds.length > 0 ? filteredRequestUserIds : null;
        }
    });

    const invitesValue = invitesSnapshot.val();
    if (invitesValue && typeof invitesValue === "object" && !Array.isArray(invitesValue)) {
        Object.entries(invitesValue as Record<string, unknown>).forEach(([otherUserId, rawInviteData]) => {
            if (otherUserId === userId || !rawInviteData || typeof rawInviteData !== "object" || Array.isArray(rawInviteData)) {
                return;
            }

            const inviteData = rawInviteData as Record<string, unknown>;

            if (inviteData.invitedBy === userId) {
                updates[`invites/${otherUserId}/invitedBy`] = null;
            }

            const inviteUserIds = toStringArray(inviteData.invites);
            const filteredInviteUserIds = inviteUserIds.filter((inviteUserId) => inviteUserId !== userId);
            if (filteredInviteUserIds.length !== inviteUserIds.length) {
                updates[`invites/${otherUserId}/invites`] = filteredInviteUserIds.length > 0 ? filteredInviteUserIds : null;
            }
        });
    }

    const userBlocksValue = userBlocksSnapshot.val();
    if (userBlocksValue && typeof userBlocksValue === "object" && !Array.isArray(userBlocksValue)) {
        Object.entries(userBlocksValue as Record<string, unknown>).forEach(([otherUserId, rawBlockedUsers]) => {
            if (otherUserId === userId || !rawBlockedUsers || typeof rawBlockedUsers !== "object" || Array.isArray(rawBlockedUsers)) {
                return;
            }

            if (Object.prototype.hasOwnProperty.call(rawBlockedUsers, userId)) {
                updates[`userBlocks/${otherUserId}/${userId}`] = null;
            }
        });
    }

    const peerIdsWithConversationUpdates = new Set<string>();

    conversationsSnapshot.docs.forEach((conversationDocument) => {
        const conversationId = conversationDocument.id;
        const conversation = conversationDocument.data() as Conversation;

        updates[`haptics/${conversationId}`] = null;

        conversation.peers
            .filter((peerId) => peerId !== userId)
            .forEach((peerId) => {
                peerIdsWithConversationUpdates.add(peerId);

                const filteredConversationIds = toStringArray(userConversations[peerId])
                    .filter((existingConversationId) => existingConversationId !== conversationId);

                userConversations[peerId] = filteredConversationIds;
                updates[`userConversationsIndex/${peerId}/${conversationId}`] = null;
            });
    });

    peerIdsWithConversationUpdates.forEach((peerId) => {
        const conversationIds = toStringArray(userConversations[peerId]);
        updates[`userConversations/${peerId}`] = conversationIds.length > 0 ? conversationIds : null;
    });

    await rootRef.update(updates);

    const bulkWriter = firestore.bulkWriter();
    bulkWriter.delete(firestore.collection("users").doc(userId));
    bulkWriter.delete(firestore.collection("pushTokens").doc(userId));
    bulkWriter.delete(firestore.collection("reports").doc(userId));

    conversationsSnapshot.docs.forEach((conversationDocument) => {
        bulkWriter.delete(conversationDocument.ref);
    });

    reportsSnapshot.docs.forEach((reportDocument) => {
        if (reportDocument.id === userId) {
            return;
        }

        const reportData = reportDocument.data();
        const reporterOwnedFields = Object.entries(reportData).reduce<Record<string, admin.firestore.FieldValue>>((fields, [field, value]) => {
            if (
                value
                && typeof value === "object"
                && !Array.isArray(value)
                && (value as { reporterId?: unknown }).reporterId === userId
            ) {
                fields[field] = admin.firestore.FieldValue.delete();
            }

            return fields;
        }, {});

        if (Object.keys(reporterOwnedFields).length > 0) {
            bulkWriter.set(reportDocument.ref, reporterOwnedFields, { merge: true });
        }
    });

    await bulkWriter.close();
}

exports.syncUserConversationsIndex = functions.database.onValueWritten(
    {
        ref: "userConversations/{userId}",
        region: FUNCTIONS_REGION
    },
    async (event) => {
        const userId = event.params.userId;

        if (typeof userId !== "string" || userId.length === 0) {
            return null;
        }

        const conversationIds = toStringArray(event.data.after.val());
        const conversationIndex = buildConversationIndex(conversationIds);

        await admin.database()
            .ref(`userConversationsIndex/${userId}`)
            .set(conversationIndex);

        return null;
    }
);

exports.deleteUserData = functionsV1
    .region(FUNCTIONS_REGION)
    .auth.user()
    .onDelete(async (user) => {
        try {
            await cleanupDeletedUserData(user.uid);
            functions.logger.log(`Deleted backend data for auth user ${user.uid}`);
        } catch (error) {
            functions.logger.error(`Failed deleting backend data for auth user ${user.uid}: ${error}`);
            throw error;
        }
    });

exports.conversationHapticSent = functions.database.onValueUpdated(
    {
        ref: "haptics/{conversationId}",
        region: FUNCTIONS_REGION
    },
    async (event) => {
        const conversationId = event.params.conversationId;

        const beforeData = convertToHaptic(event.data.before.val());

        if (!beforeData || !beforeData.timestamp) {
            functions.logger.error(`Before data is empty for conversation with id: ${conversationId}`);
            return null;
        }

        const afterData = convertToHaptic(event.data.after.val());

        if (!afterData || !afterData.timestamp) {
            functions.logger.error(`After data is empty for conversation with id: ${conversationId}`);
            return null;
        }

        const newTimestamp = afterData.timestamp.seconds;
        const oldTimestamp = beforeData.timestamp.seconds;

        if (newTimestamp - oldTimestamp <= hapticNotificationBarierInSeconds) {
            functions.logger.log(`Timestamp is less than ${hapticNotificationBarierInSeconds} seconds for conversation with id: ${conversationId}`);
            return null;
        }

        try {
            const senderId = afterData.senderId;

            const senderRef = firestore.collection('users').doc(senderId);
            const senderDoc = await senderRef.get();

            if (!senderDoc.exists) {
                functions.logger.error(`Sender document with id: ${senderId}, does not exist`);
                return null;
            }

            const sender = senderDoc.data() as Profile | undefined;

            if (!sender || !sender.name || sender.name.length === 0) {
                functions.logger.error(`No name found for sender with id: ${senderId}.`);
                return null;
            }

            const conversationRef = firestore.collection('conversations').doc(conversationId);
            const conversationDoc = await conversationRef.get();

            if (!conversationDoc.exists) {
                functions.logger.error(`Conversation document with id: ${conversationId}, does not exist`);
                return null;
            }

            const conversation = conversationDoc.data() as Conversation | undefined;

            if (!conversation || !conversation.peers || conversation.peers.length === 0) {
                functions.logger.error(`No peers found for conversation with id: ${conversationId}`);
                return null;
            }

            const peers = conversation.peers;

            // Verify sender is actually a peer in this conversation
            if (!peers.includes(senderId)) {
                functions.logger.error(`Sender ${senderId} is not a peer in conversation ${conversationId}`);
                return null;
            }

            const peerIdsToNotify = peers.filter(peerId => peerId !== senderId);

            let title: string;
            let body: string;

            const haptic = afterData.type as HapticType | undefined;
            if (haptic) {
                const emojiInfo = afterData.type as EmojiInfo | undefined;
                if (haptic.type === "emoji" && emojiInfo && emojiInfo.emoji && emojiInfo.emoji.length > 0) {
                    title = `${sender.name} is sending you ${emojiInfo.emoji}`;
                    body = `Reply now`;
                } else if (haptic.type === "sketch") {
                    title = `${sender.name} is sending you a 🎨`;
                    body = `Check it out before it disappears!`;
                } else if (haptic.type === "default") {
                    title = `${sender.name} is sending you love!`;
                    body = `Reply now`;
                } else if (haptic.type === "empty") {
                    title = `${sender.name} has accepted your friend request!`;
                    body = `Send them some love 💖`;
                } else {
                    functions.logger.error(`Invalid haptic type: ${afterData.type}`);
                    return null;
                }
            } else {
                functions.logger.error(`Invalid haptic type: ${afterData.type}`);
                return null;
            }

            for (const peerId of peerIdsToNotify) {
                await sendNotificationToUser(peerId, {
                    data: {
                        "conversationId": conversationId
                    },
                    notification: {
                        title: title,
                        body: body,
                    },
                    apns: {
                        payload: {
                            aps: {
                                badge: 1,
                                category: notificationCategoryNewMessage,
                                sound: {
                                    name: "default",
                                    volume: 1
                                },
                                threadId: conversationId
                            }
                        }
                    }
                });

                functions.logger.log(`Notification sent to peer id: ${peerId}`);
            }
        } catch (error) {
            functions.logger.error(`Error fetching peers or sending notification: ${error}`);
        }

        return null;
    });

exports.friendRequestOnCreated = functions.database.onValueCreated(
    {
        ref: "requests/{userId}",
        region: FUNCTIONS_REGION
    },
    async (event) => {
        const data = event.data.val();
        if (!data || (Array.isArray(data) && data.length === 0)) {
            return null;
        }

        await sendNewFriendsRequestNotification(event.params.userId);

        return null;
    });

exports.friendRequestOnUpdated = functions.database.onValueUpdated(
    {
        ref: "requests/{userId}",
        region: FUNCTIONS_REGION
    },
    async (event) => {
        const beforeData = event.data.before.val();
        const afterData = event.data.after.val();

        const beforeSet = new Set(Array.isArray(beforeData) ? beforeData as string[] : []);
        const afterSet = new Set(Array.isArray(afterData) ? afterData as string[] : []);

        let hasNewRequests = false;
        afterSet.forEach(element => {
            if (!beforeSet.has(element)) {
                hasNewRequests = true;
            }
        });

        if (!hasNewRequests) {
            return null;
        }

        await sendNewFriendsRequestNotification(event.params.userId);

        return null
    });

exports.sendAyo = functions.https.onCall({
    region: FUNCTIONS_REGION,
    enforceAppCheck: true,
},
    async (event) => {
        try {
            const senderId = event.auth?.uid;

            if (!senderId) {
                functions.logger.error(`No senderId specified`);
                throw new HttpsError("unauthenticated", "The function must be called with auth.")
            }

            const senderRef = firestore.collection('users').doc(senderId);
            const senderDoc = await senderRef.get();

            if (!senderDoc.exists) {
                functions.logger.error(`Sender document with id: ${senderId}, does not exist`);
                throw new HttpsError("failed-precondition", "Sender's document was not found.");
            }

            const sender = senderDoc.data() as Profile | undefined;

            if (!sender || !sender.name || sender.name.length === 0) {
                functions.logger.error(`No name found for sender with id: ${senderId}.`);
                throw new HttpsError("failed-precondition", "Sender's name was not found.");
            }

            const conversationId = event.data.conversationId;

            if (!conversationId) {
                functions.logger.error(`No conversationId specified`);
                throw new HttpsError("invalid-argument", "The function must be called with a specified conversationId.")
            }

            const conversationRef = firestore.collection('conversations').doc(conversationId);
            const conversationDoc = await conversationRef.get();

            if (!conversationDoc.exists) {
                functions.logger.error(`Conversation document with id: ${conversationId}, does not exist`);
                throw new HttpsError("failed-precondition", "The conversation with specified conversationId does not exist.");
            }

            const conversation = conversationDoc.data() as Conversation | undefined;

            if (!conversation || !conversation.peers || conversation.peers.length === 0) {
                functions.logger.error(`No peers found for conversation with id: ${conversationId}`);
                throw new HttpsError("failed-precondition", "The conversation with specified conversationId does not contain any peers.");
            }

            const peers = conversation.peers;

            // Verify sender is a peer in this conversation
            if (!peers.includes(senderId)) {
                functions.logger.error(`Sender ${senderId} is not a peer in conversation ${conversationId}`);
                throw new HttpsError("permission-denied", "User is not a peer in this conversation.");
            }

            const nowInSeconds = Math.floor(Date.now() / 1000);
            const throttleResult = await admin.database()
                .ref(`ayoThrottles/${senderId}/${conversationId}`)
                .transaction((lastTimestamp: number | null) => {
                    if (typeof lastTimestamp === "number" && nowInSeconds - lastTimestamp < ayoNotificationBarrierInSeconds) {
                        return;
                    }

                    return nowInSeconds;
                });

            if (!throttleResult.committed) {
                throw new HttpsError("resource-exhausted", "Ayo was sent too recently for this conversation.");
            }

            const peerIdsToNotify = peers.filter(peerId => peerId !== senderId);

            for (const peerId of peerIdsToNotify) {
                await sendNotificationToUser(peerId, {
                    data: {
                        "conversationId": conversationId
                    },
                    notification: {
                        title: `Ayo! This is ${sender.name}!`,
                        body: `Pss, I've got something to tell you 🤫`
                    },
                    apns: {
                        payload: {
                            aps: {
                                badge: 1,
                                category: notificationCategoryAyo,
                                sound: {
                                    name: "default",
                                    volume: 1
                                },
                                threadId: conversationId
                            }
                        }
                    }
                });

                functions.logger.log(`Ayo notification sent to peer id: ${peerId}`);
            }
        } catch (error) {
            if (error instanceof HttpsError) {
                throw error;
            }
            functions.logger.error(`Error fetching peers or sending notification: ${error}`);
            throw new HttpsError("unknown", `Error sending ayo: ${error}`);
        }
    })

exports.createConversation = functions.https.onCall({
    region: FUNCTIONS_REGION,
    enforceAppCheck: true,
}, async (event) => {
    try {
        const userId = event.auth?.uid;

        if (!userId) {
            throw new HttpsError("unauthenticated", "The function must be called with auth.");
        }

        const peerId = event.data.peerId;

        if (!peerId) {
            throw new HttpsError("invalid-argument", "The function must be called with peerId.");
        }

        if (userId === peerId) {
            throw new HttpsError("invalid-argument", "Cannot create conversation with yourself.");
        }

        if (!(await userExists(peerId))) {
            throw new HttpsError("not-found", "The peer user does not exist.");
        }

        await checkUsersForBlock(userId, peerId);

        const [userRequestsSnapshot, peerRequestsSnapshot] = await Promise.all([
            admin.database().ref(`requests/${userId}`).get(),
            admin.database().ref(`requests/${peerId}`).get()
        ]);

        // Verify a pending request exists (either direction)
        const userRequests = toStringArray(userRequestsSnapshot.val());
        const peerRequests = toStringArray(peerRequestsSnapshot.val());

        const hasPendingRequest = userRequests.includes(peerId) || peerRequests.includes(userId);

        if (!hasPendingRequest) {
            throw new HttpsError("failed-precondition", "No pending friend request exists between these users.");
        }

        const conversationId = firestore.collection("conversations").doc().id;
        const conversationData = {
            id: conversationId,
            peers: [userId, peerId],
            timestamp: new Date()
        };

        await firestore
            .collection("conversations")
            .doc(conversationId)
            .set(conversationData);

        try {
            const addConversationResult = await admin.database()
                .ref("userConversations")
                .transaction((currentData: unknown) => {
                    const conversations = toStringArrayMap(currentData);

                    if (sharedConversationExists(conversations, userId, peerId)) {
                        return;
                    }

                    const userIdResult = addConversationToUserConversations(conversations, conversationId, userId);
                    if (!userIdResult) {
                        return;
                    }

                    const peerIdResult = addConversationToUserConversations(conversations, conversationId, peerId);
                    if (!peerIdResult) {
                        return;
                    }

                    return conversations;
                });

            if (!addConversationResult.committed) {
                throw new HttpsError("already-exists", "Conversation already exists between these users.");
            }

            const updates: Record<string, unknown> = {};

            const filteredUserRequests = userRequests.filter((id) => id !== peerId);
            updates[`requests/${userId}`] = filteredUserRequests.length > 0 ? filteredUserRequests : null;

            const filteredPeerRequests = peerRequests.filter((id) => id !== userId);
            updates[`requests/${peerId}`] = filteredPeerRequests.length > 0 ? filteredPeerRequests : null;

            updates[`userConversationsIndex/${userId}/${conversationId}`] = true;
            updates[`userConversationsIndex/${peerId}/${conversationId}`] = true;
            updates[`haptics/${conversationId}`] = createEmptyHaptic(userId);

            await admin.database().ref().update(updates);
        } catch (error) {
            await firestore
                .collection("conversations")
                .doc(conversationId)
                .delete()
                .catch(() => null);
            throw error;
        }

        return { conversationId };

    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        functions.logger.error(`Error creating conversation: ${error}`);
        throw new HttpsError("unknown", `Error creating conversation: ${error}`);
    }
});

exports.sendHaptic = functions.https.onCall({
    region: FUNCTIONS_REGION,
    enforceAppCheck: true,
}, async (event) => {
    try {
        const senderId = event.auth?.uid;

        if (!senderId) {
            throw new HttpsError("unauthenticated", "The function must be called with auth.");
        }

        const conversationId = event.data.conversationId;
        if (typeof conversationId !== "string" || conversationId.length === 0) {
            throw new HttpsError("invalid-argument", "The function must be called with conversationId.");
        }

        const conversationDoc = await firestore
            .collection("conversations")
            .doc(conversationId)
            .get();

        if (!conversationDoc.exists) {
            throw new HttpsError("not-found", "Conversation not found.");
        }

        const conversation = conversationDoc.data() as Conversation;
        if (!conversation.peers.includes(senderId)) {
            throw new HttpsError("permission-denied", "User is not a peer in this conversation.");
        }

        validateHapticPayload(event.data.haptic, senderId);

        await admin.database()
            .ref(`haptics/${conversationId}`)
            .set(event.data.haptic);

        return { success: true };
    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        functions.logger.error(`Error sending haptic: ${error}`);
        throw new HttpsError("unknown", `Error sending haptic: ${error}`);
    }
});

exports.denyConversationRequest = functions.https.onCall({
    region: FUNCTIONS_REGION,
    enforceAppCheck: true,
}, async (event) => {
    try {
        const userId = event.auth?.uid;

        if (!userId) {
            throw new HttpsError("unauthenticated", "The function must be called with auth.");
        }

        const peerId = event.data.peerId;

        if (!peerId) {
            throw new HttpsError("invalid-argument", "The function must be called with peerId.");
        }

        // Use transaction to safely remove from requests
        const requestsRef = admin.database().ref(`requests/${userId}`);

        await requestsRef.transaction((currentData: string[] | null) => {
            if (!currentData) {
                return currentData;
            }

            const updated = currentData.filter(id => id !== peerId);
            return updated.length > 0 ? updated : null;
        });

        return { success: true };

    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        functions.logger.error(`Error denying conversation request: ${error}`);
        throw new HttpsError("unknown", `Error denying conversation request: ${error}`);
    }
});

exports.removeConversation = functions.https.onCall({
    region: FUNCTIONS_REGION,
    enforceAppCheck: true,
}, async (event) => {
    try {
        const userId = event.auth?.uid;

        if (!userId) {
            throw new HttpsError("unauthenticated", "The function must be called with auth.");
        }

        const conversationId = event.data.conversationId;

        if (!conversationId) {
            throw new HttpsError("invalid-argument", "The function must be called with conversationId.");
        }

        // Get conversation to verify user is a peer
        const conversationDoc = await firestore
            .collection('conversations')
            .doc(conversationId)
            .get();

        if (!conversationDoc.exists) {
            throw new HttpsError("not-found", "Conversation not found.");
        }

        const conversation = conversationDoc.data() as Conversation;

        if (!conversation.peers.includes(userId)) {
            throw new HttpsError("permission-denied", "User is not a peer in this conversation.");
        }

        const peerId = conversation.peers.find(id => id !== userId);

        if (!peerId) {
            throw new HttpsError("failed-precondition", "Could not find peer in conversation.");
        }

        // Read only the two relevant users' conversations
        const updates: { [key: string]: any } = {};
        const removeConversationResult = await admin.database()
            .ref("userConversations")
            .transaction((currentData: unknown) => {
                const conversations = toStringArrayMap(currentData);

                removeConversationFromUserConversations(conversations, conversationId, userId);
                removeConversationFromUserConversations(conversations, conversationId, peerId);

                return conversations;
            });

        if (!removeConversationResult.committed) {
            throw new HttpsError("aborted", "Failed to remove conversation membership.");
        }

        updates[`userConversationsIndex/${userId}/${conversationId}`] = null;
        updates[`userConversationsIndex/${peerId}/${conversationId}`] = null;
        updates[`haptics/${conversationId}`] = null;

        await admin.database().ref().update(updates);

        // Delete conversation document from Firestore
        await firestore
            .collection('conversations')
            .doc(conversationId)
            .delete();

        return { success: true };

    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        functions.logger.error(`Error removing conversation: ${error}`);
        throw new HttpsError("unknown", `Error removing conversation: ${error}`);
    }
});

exports.sendRequest = functions.https.onCall({
    region: FUNCTIONS_REGION,
    enforceAppCheck: true,
}, async (event) => {
    try {
        const userId = event.auth?.uid;

        if (!userId) {
            throw new HttpsError("unauthenticated", "The function must be called with auth.");
        }

        const peerId = event.data.peerId;

        if (!peerId) {
            throw new HttpsError("invalid-argument", "The function must be called with peerId.");
        }

        if (userId === peerId) {
            throw new HttpsError("invalid-argument", "Cannot send a friend request to yourself.");
        }

        await acquireThrottle(`requestThrottles/${userId}/${peerId}`,
            sendRequestBarrierInSeconds,
            "Friend request sent too recently.");

        if (!(await userExists(peerId))) {
            throw new HttpsError("not-found", "The peer user does not exist.");
        }

        // Check for blocks (parallel)
        const [userBlocksSnapshot, peerBlocksSnapshot] = await Promise.all([
            admin.database().ref(`userBlocks/${userId}/${peerId}`).get(),
            admin.database().ref(`userBlocks/${peerId}/${userId}`).get()
        ]);

        if (userBlocksSnapshot.exists()) {
            throw new HttpsError("failed-precondition", "Cannot send request - user is blocked.");
        }

        if (peerBlocksSnapshot.exists()) {
            throw new HttpsError("failed-precondition", "Cannot send request - user is blocked.");
        }

        // Check for existing conversation
        const [userConvSnapshot, peerConvSnapshot] = await Promise.all([
            admin.database().ref(`userConversations/${userId}`).get(),
            admin.database().ref(`userConversations/${peerId}`).get()
        ]);

        const userConvList = toStringArray(userConvSnapshot.val());
        const peerConvList = toStringArray(peerConvSnapshot.val());

        const userConvSet = new Set(userConvList);
        for (const convId of peerConvList) {
            if (userConvSet.has(convId)) {
                throw new HttpsError("already-exists", "Already friends with this user.");
            }
        }

        // Use transaction to safely add to peer's requests
        const requestsRef = admin.database().ref(`requests/${peerId}`);

        const result = await requestsRef.transaction((currentData: string[] | null) => {
            const requests = currentData || [];

            if (requests.includes(userId)) {
                return undefined; // Abort transaction
            }

            requests.push(userId);
            return requests;
        });

        if (!result.committed) {
            throw new HttpsError("already-exists", "Request already sent.");
        }

        return { success: true };

    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        functions.logger.error(`Error sending request: ${error}`);
        throw new HttpsError("unknown", `Error sending request: ${error}`);
    }
});

exports.blockUser = functions.https.onCall({
    region: FUNCTIONS_REGION,
    enforceAppCheck: true,
}, async (event) => {
    try {
        const userId = event.auth?.uid;

        if (!userId) {
            throw new HttpsError("unauthenticated", "The function must be called with auth.");
        }

        const userIdToBlock = event.data.userIdToBlock;

        if (!userIdToBlock) {
            throw new HttpsError("invalid-argument", "The function must be called with userIdToBlock.");
        }

        if (userId === userIdToBlock) {
            throw new HttpsError("invalid-argument", "Cannot block yourself.");
        }

        if (!(await userExists(userIdToBlock))) {
            throw new HttpsError("not-found", "The blocked user does not exist.");
        }

        const addBlockResult = await admin.database()
            .ref(`userBlocks/${userId}`)
            .transaction((currentData: Record<string, number> | null) => {
                const blockedUserIds = currentData ?? {};

                if (blockedUserIds[userIdToBlock] != null) {
                    return;
                }

                return {
                    ...blockedUserIds,
                    [userIdToBlock]: Date.now()
                };
            });

        if (!addBlockResult.committed) {
            return { success: true, alreadyBlocked: true };
        }

        // Also remove any pending requests between the users
        const updates: { [key: string]: any } = {};

        const [userRequestsSnapshot, peerRequestsSnapshot] = await Promise.all([
            admin.database().ref(`requests/${userId}`).get(),
            admin.database().ref(`requests/${userIdToBlock}`).get()
        ]);

        if (userRequestsSnapshot.exists()) {
            const userRequests = toStringArray(userRequestsSnapshot.val()).filter(id => id !== userIdToBlock);
            updates[`requests/${userId}`] = userRequests.length > 0 ? userRequests : null;
        }

        if (peerRequestsSnapshot.exists()) {
            const peerRequests = toStringArray(peerRequestsSnapshot.val()).filter(id => id !== userId);
            updates[`requests/${userIdToBlock}`] = peerRequests.length > 0 ? peerRequests : null;
        }

        if (Object.keys(updates).length > 0) {
            await admin.database().ref().update(updates);
        }

        return { success: true, alreadyBlocked: false };

    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        functions.logger.error(`Error blocking user: ${error}`);
        throw new HttpsError("unknown", `Error blocking user: ${error}`);
    }
});

exports.updateInvites = functions.https.onCall({
    region: FUNCTIONS_REGION,
    enforceAppCheck: true,
}, async (event) => {
    try {
        const userId = event.auth?.uid;

        if (!userId) {
            throw new HttpsError("unauthenticated", "The function must be called with auth.");
        }

        const peerId = event.data.peerId;

        if (!peerId) {
            throw new HttpsError("invalid-argument", "The function must be called with peerId.");
        }

        if (peerId === userId) {
            throw new HttpsError("invalid-argument", "Cannot invite yourself.");
        }

        await acquireThrottle(`inviteThrottles/${userId}/${peerId}`,
            updateInvitesBarrierInSeconds,
            "Invite update sent too recently.");

        if (!(await userExists(peerId))) {
            throw new HttpsError("not-found", "The invited user does not exist.");
        }

        // Use transaction to check and set invitedBy atomically
        const peerInvitesRef = admin.database().ref(`invites/${peerId}`);
        const peerResult = await peerInvitesRef.transaction((currentData: any) => {
            if (currentData) {
                // Peer has already been invited
                return undefined; // Abort
            }
            return { invitedBy: userId };
        });

        if (!peerResult.committed) {
            return { success: true, alreadyInvited: true };
        }

        // Use transaction to safely add to user's invites list
        const userInvitesRef = admin.database().ref(`invites/${userId}/invites`);
        await userInvitesRef.transaction((currentData: string[] | null) => {
            const invites = currentData || [];
            if (!invites.includes(peerId)) {
                invites.push(peerId);
            }
            return invites;
        });

        return { success: true, alreadyInvited: false };

    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        functions.logger.error(`Error updating invites: ${error}`);
        throw new HttpsError("unknown", `Error updating invites: ${error}`);
    }
});

async function sendNewFriendsRequestNotification(userId: string) {
    try {
        await sendNotificationToUser(userId, {
            notification: {
                title: `New friend request`,
            },
            apns: {
                payload: {
                    aps: {
                        badge: 1,
                        category: notificationCategoryFriendRequest,
                        sound: {
                            name: "default",
                            volume: 1
                        }
                    }
                }
            }
        });

        functions.logger.log(`Friend request notification sent to user id: ${userId}`);
    } catch (error) {
        functions.logger.error(`Error sending notification: ${error}`);
    }
}
