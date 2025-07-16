import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();

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
    peers: string[];
}

interface UserTokensInfo {
    tokens: Array<{ token: string }>;
}

interface Profile {
    name: string;
}

const hapticNotificationBarierInSeconds = 5;

const notificationCategoryNewMessage = "newMessage";

const notificationCategoryFriendRequest = "friendRequest";

const notificationCategoryAyo = "ayo";

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
    const tokensRef = admin.firestore().collection('pushTokens').doc(userId);
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

            const senderRef = admin.firestore().collection('users').doc(senderId);
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

            const conversationRef = admin.firestore().collection('conversations').doc(conversationId);
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
},
    async (event) => {
        try {
            const senderId = event.auth?.uid;

            if (!senderId) {
                functions.logger.error(`No senderId specified`);
                throw new HttpsError("unauthenticated", "The function must be called with auth.")
            }

            const senderRef = admin.firestore().collection('users').doc(senderId);
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

            const conversationRef = admin.firestore().collection('conversations').doc(conversationId);
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

            const peerIdsToNotify = peers.filter(peerId => peerId !== senderId);

            for (const peerId of peerIdsToNotify) {
                for (let i = 0; i < 15; i++) {
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
                }

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

        // Check for blocks (parallel)
        const [userBlocksSnapshot, peerBlocksSnapshot] = await Promise.all([
            admin.database().ref(`userBlocks/${userId}/${peerId}`).get(),
            admin.database().ref(`userBlocks/${peerId}/${userId}`).get()
        ]);

        if (userBlocksSnapshot.exists()) {
            throw new HttpsError("failed-precondition", "Cannot create conversation - user is blocked.");
        }

        if (peerBlocksSnapshot.exists()) {
            throw new HttpsError("failed-precondition", "Cannot create conversation - user is blocked.");
        }

        // Read only the two relevant users' data (not entire nodes)
        const [userConvSnapshot, peerConvSnapshot, userRequestsSnapshot, peerRequestsSnapshot] = await Promise.all([
            admin.database().ref(`userConversations/${userId}`).get(),
            admin.database().ref(`userConversations/${peerId}`).get(),
            admin.database().ref(`requests/${userId}`).get(),
            admin.database().ref(`requests/${peerId}`).get()
        ]);

        const userConvList: string[] = userConvSnapshot.exists() ? (userConvSnapshot.val() as string[] || []) : [];
        const peerConvList: string[] = peerConvSnapshot.exists() ? (peerConvSnapshot.val() as string[] || []) : [];

        // Check for existing shared conversation
        const userConvSet = new Set(userConvList);
        for (const convId of peerConvList) {
            if (userConvSet.has(convId)) {
                throw new HttpsError("already-exists", "Conversation already exists between these users.");
            }
        }

        // Verify a pending request exists (either direction)
        const userRequests: string[] = userRequestsSnapshot.exists() ? (userRequestsSnapshot.val() as string[] || []) : [];
        const peerRequests: string[] = peerRequestsSnapshot.exists() ? (peerRequestsSnapshot.val() as string[] || []) : [];

        const hasPendingRequest = userRequests.includes(peerId) || peerRequests.includes(userId);

        if (!hasPendingRequest) {
            throw new HttpsError("failed-precondition", "No pending friend request exists between these users.");
        }

        // Create conversation document
        const conversationData = {
            peers: [userId, peerId],
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        };

        const conversationRef = await admin.firestore()
            .collection('conversations')
            .add(conversationData);

        const conversationId = conversationRef.id;

        // Build atomic RTDB update
        const updates: { [key: string]: any } = {};

        // Add conversation to both users
        updates[`userConversations/${userId}/${userConvList.length}`] = conversationId;
        updates[`userConversations/${peerId}/${peerConvList.length}`] = conversationId;

        // Remove from requests (both directions)
        const filteredUserRequests = userRequests.filter(id => id !== peerId);
        updates[`requests/${userId}`] = filteredUserRequests.length > 0 ? filteredUserRequests : null;

        const filteredPeerRequests = peerRequests.filter(id => id !== userId);
        updates[`requests/${peerId}`] = filteredPeerRequests.length > 0 ? filteredPeerRequests : null;

        // Apply all RTDB updates atomically
        await admin.database().ref().update(updates);

        // Send empty haptic to initialize the conversation
        const emptyHaptic = {
            senderId: userId,
            timestamp: Date.now() / 1000,
            type: {
                type: "empty"
            }
        };

        await admin.database()
            .ref(`haptics/${conversationId}`)
            .set(emptyHaptic);

        return { conversationId };

    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        functions.logger.error(`Error creating conversation: ${error}`);
        throw new HttpsError("unknown", `Error creating conversation: ${error}`);
    }
});

exports.denyConversationRequest = functions.https.onCall({
    region: FUNCTIONS_REGION,
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
        const conversationDoc = await admin.firestore()
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
        const [userConvSnapshot, peerConvSnapshot] = await Promise.all([
            admin.database().ref(`userConversations/${userId}`).get(),
            admin.database().ref(`userConversations/${peerId}`).get()
        ]);

        const updates: { [key: string]: any } = {};

        if (userConvSnapshot.exists()) {
            const userConvList = (userConvSnapshot.val() as string[]).filter(id => id !== conversationId);
            updates[`userConversations/${userId}`] = userConvList.length > 0 ? userConvList : null;
        }

        if (peerConvSnapshot.exists()) {
            const peerConvList = (peerConvSnapshot.val() as string[]).filter(id => id !== conversationId);
            updates[`userConversations/${peerId}`] = peerConvList.length > 0 ? peerConvList : null;
        }

        // Remove haptics
        updates[`haptics/${conversationId}`] = null;

        // Apply all RTDB updates atomically
        await admin.database().ref().update(updates);

        // Delete conversation document from Firestore
        await admin.firestore()
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

        const userConvList: string[] = userConvSnapshot.exists() ? (userConvSnapshot.val() as string[] || []) : [];
        const peerConvList: string[] = peerConvSnapshot.exists() ? (peerConvSnapshot.val() as string[] || []) : [];

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

        // Add block entry
        await admin.database()
            .ref(`userBlocks/${userId}/${userIdToBlock}`)
            .set(admin.database.ServerValue.TIMESTAMP);

        // Also remove any pending requests between the users
        const updates: { [key: string]: any } = {};

        const [userRequestsSnapshot, peerRequestsSnapshot] = await Promise.all([
            admin.database().ref(`requests/${userId}`).get(),
            admin.database().ref(`requests/${userIdToBlock}`).get()
        ]);

        if (userRequestsSnapshot.exists()) {
            const userRequests = (userRequestsSnapshot.val() as string[]).filter(id => id !== userIdToBlock);
            updates[`requests/${userId}`] = userRequests.length > 0 ? userRequests : null;
        }

        if (peerRequestsSnapshot.exists()) {
            const peerRequests = (peerRequestsSnapshot.val() as string[]).filter(id => id !== userId);
            updates[`requests/${userIdToBlock}`] = peerRequests.length > 0 ? peerRequests : null;
        }

        if (Object.keys(updates).length > 0) {
            await admin.database().ref().update(updates);
        }

        return { success: true };

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
