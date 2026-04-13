const admin = require("firebase-admin");
const { randomUUID } = require("crypto");

const projectId = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || process.argv[2];
const databaseURL = process.env.FIREBASE_DATABASE_URL || process.argv[3];

if (!projectId) {
    console.error("Missing project id. Set GOOGLE_CLOUD_PROJECT or pass it as the first argument.");
    process.exit(1);
}

if (!databaseURL) {
    console.error("Missing Realtime Database URL. Set FIREBASE_DATABASE_URL or pass it as the second argument.");
    process.exit(1);
}

admin.initializeApp({
    projectId,
    databaseURL,
});

function toStringArray(value) {
    if (Array.isArray(value)) {
        return value.filter((entry) => typeof entry === "string");
    }

    if (value && typeof value === "object") {
        return Object.values(value).filter((entry) => typeof entry === "string");
    }

    return [];
}

function buildConversationIndex(conversationIds) {
    const uniqueConversationIds = Array.from(new Set(conversationIds));

    if (uniqueConversationIds.length === 0) {
        return null;
    }

    return uniqueConversationIds.reduce((index, conversationId) => {
        index[conversationId] = true;
        return index;
    }, {});
}

function createEmptyHaptic(senderId) {
    const appleReferenceDateOffsetInSeconds = 978307200;

    return {
        id: randomUUID(),
        senderId,
        timestamp: (Date.now() / 1000) - appleReferenceDateOffsetInSeconds,
        type: {
            type: "empty",
            fromRect: [[0, 0], [0, 0]],
            location: [0, 0],
        },
    };
}

async function main() {
    const database = admin.database();
    const firestore = admin.firestore();

    const [userConversationsSnapshot, hapticsSnapshot] = await Promise.all([
        database.ref("userConversations").get(),
        database.ref("haptics").get(),
    ]);

    const userConversations = userConversationsSnapshot.val() || {};
    const haptics = hapticsSnapshot.val() || {};

    const indexUpdates = {};
    const missingHapticConversationIds = new Set();

    Object.entries(userConversations).forEach(([userId, rawConversationIds]) => {
        const conversationIds = toStringArray(rawConversationIds);
        indexUpdates[`userConversationsIndex/${userId}`] = buildConversationIndex(conversationIds);

        conversationIds.forEach((conversationId) => {
            if (haptics[conversationId] == null) {
                missingHapticConversationIds.add(conversationId);
            }
        });
    });

    const hapticUpdates = {};

    for (const conversationId of missingHapticConversationIds) {
        const conversationSnapshot = await firestore.collection("conversations").doc(conversationId).get();

        if (!conversationSnapshot.exists) {
            console.warn(`Skipping missing haptic for ${conversationId}: conversation document does not exist.`);
            continue;
        }

        const conversation = conversationSnapshot.data() || {};
        const senderId = Array.isArray(conversation.peers)
            ? conversation.peers.find((peerId) => typeof peerId === "string")
            : null;

        if (!senderId) {
            console.warn(`Skipping missing haptic for ${conversationId}: no valid peer found.`);
            continue;
        }

        hapticUpdates[`haptics/${conversationId}`] = createEmptyHaptic(senderId);
    }

    await database.ref().update({
        ...indexUpdates,
        ...hapticUpdates,
    });

    console.log(JSON.stringify({
        usersProcessed: Object.keys(userConversations).length,
        indexEntriesWritten: Object.keys(indexUpdates).length,
        missingHapticsSeeded: Object.keys(hapticUpdates).length,
    }, null, 2));
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
