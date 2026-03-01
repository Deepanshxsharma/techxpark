import { db } from '../firebase';
import {
    collection,
    doc,
    setDoc,
    addDoc,
    updateDoc,
    getDocs,
    query,
    where,
    serverTimestamp,
    increment,
    writeBatch,
    onSnapshot,
    orderBy
} from 'firebase/firestore';

// Generate consistent conversation ID — same two people ALWAYS get same ID
export function getConversationId(uid1, uid2) {
    return [uid1, uid2].sort().join('_');
}

// Send a message
export async function sendMessage({
    senderId,
    senderName,
    senderRole,
    receiverId,
    receiverName,
    receiverRole,
    text,
    lotId = null
}) {
    if (!text?.trim()) return;
    if (!senderId || !receiverId) {
        throw new Error('Missing sender or receiver');
    }

    const convId = getConversationId(senderId, receiverId);
    const convRef = doc(db, 'conversations', convId);

    // Create or update conversation doc
    await setDoc(
        convRef,
        {
            participants: [senderId, receiverId],
            participantNames: {
                [senderId]: senderName || 'Unknown',
                [receiverId]: receiverName || 'Unknown'
            },
            participantRoles: {
                [senderId]: senderRole,
                [receiverId]: receiverRole
            },
            lotId: lotId || null,
            lastMessage: text.trim(),
            lastMessageTime: serverTimestamp(),
            lastMessageSenderId: senderId,
            type: `${senderRole}_${receiverRole}`,
            [`unreadCount.${receiverId}`]: increment(1),
            [`unreadCount.${senderId}`]: 0
        },
        { merge: true }
    );

    // Add message to subcollection
    await addDoc(
        collection(db, 'conversations', convId, 'messages'),
        {
            senderId,
            senderName: senderName || 'Unknown',
            senderRole,
            text: text.trim(),
            timestamp: serverTimestamp(),
            read: false,
            readAt: null
        }
    );
}

// Mark all messages in conversation as read
export async function markAsRead(convId, userId) {
    if (!convId || !userId) return;
    try {
        // Reset unread count for this user
        await updateDoc(
            doc(db, 'conversations', convId),
            { [`unreadCount.${userId}`]: 0 }
        );

        // Mark individual messages as read
        const unreadSnap = await getDocs(
            query(
                collection(db, 'conversations', convId, 'messages'),
                where('read', '==', false),
                where('senderId', '!=', userId)
            )
        );

        if (unreadSnap.empty) return;

        const batch = writeBatch(db);
        unreadSnap.docs.forEach((d) => {
            batch.update(d.ref, {
                read: true,
                readAt: serverTimestamp()
            });
        });
        await batch.commit();
    } catch (err) {
        console.error('markAsRead error:', err);
    }
}

// Real-time conversations listener
export function listenToConversations(userId, callback) {
    if (!userId) return () => {};

    return onSnapshot(
        query(
            collection(db, 'conversations'),
            where('participants', 'array-contains', userId),
            orderBy('lastMessageTime', 'desc')
        ),
        (snap) => {
            callback(
                snap.docs.map((d) => ({ id: d.id, ...d.data() }))
            );
        },
        (err) => {
            console.error('Conversations listener:', err);
        }
    );
}

// Real-time messages listener for a conversation
export function listenToMessages(convId, callback) {
    if (!convId) return () => {};

    return onSnapshot(
        query(
            collection(db, 'conversations', convId, 'messages'),
            orderBy('timestamp', 'asc')
        ),
        (snap) => {
            callback(
                snap.docs.map((d) => ({ id: d.id, ...d.data() }))
            );
        },
        (err) => {
            console.error('Messages listener:', err);
        }
    );
}

// Get total unread count for a user (for sidebar badge)
export function listenToUnreadCount(userId, callback) {
    if (!userId) return () => {};

    return onSnapshot(
        query(
            collection(db, 'conversations'),
            where('participants', 'array-contains', userId)
        ),
        (snap) => {
            let total = 0;
            snap.docs.forEach((d) => {
                const data = d.data();
                total += (data.unreadCount?.[userId] || 0);
            });
            callback(total);
        },
        (err) => {
            console.error('Unread count listener:', err);
        }
    );
}
