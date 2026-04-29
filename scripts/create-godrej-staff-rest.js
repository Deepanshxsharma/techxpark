/**
 * Create Godrej BKC Staff Accounts using REST API
 * This bypasses the need for firebase-admin and service accounts by using the Web API Key.
 */

const API_KEY = "AIzaSyBIzofvIykqBqdadR66B7vE2Tmsn32KLpE";
const PROJECT_ID = "techxpark-67c25";

const STAFF_ACCOUNTS = [
  {
    email: 'admin@godrejbkc.com',
    password: 'Godrej@2026',
    name: 'Godrej Admin',
    role: 'admin',
  },
  {
    email: 'operator@godrejbkc.com',
    password: 'Operator@2026',
    name: 'B1 Zone Operator',
    role: 'operator',
  },
  {
    email: 'deepansh@techxpark.com',
    password: 'Admin@2026',
    name: 'Deepansh (Super Admin)',
    role: 'superadmin',
  },
];

async function createStaff() {
  console.log('🔐 Creating Godrej BKC Staff Accounts via REST...\n');

  for (const staff of STAFF_ACCOUNTS) {
    try {
      console.log(`Processing ${staff.email}...`);
      
      // 1. Create User via Identity Toolkit
      const signupRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: staff.email,
          password: staff.password,
          returnSecureToken: true
        })
      });
      
      const signupData = await signupRes.json();
      
      let localId;
      let idToken;
      if (signupRes.ok) {
        localId = signupData.localId;
        idToken = signupData.idToken;
        console.log(`  ✅ Auth Account created (uid: ${localId})`);
      } else {
        if (signupData.error.message === 'EMAIL_EXISTS') {
           console.log(`  ℹ️ Auth Account already exists for ${staff.email}`);
           
           // We need the localId to update Firestore. Let's sign in to get it.
           const signinRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
             method: 'POST',
             headers: { 'Content-Type': 'application/json' },
             body: JSON.stringify({
               email: staff.email,
               password: staff.password,
               returnSecureToken: true
             })
           });
           const signinData = await signinRes.json();
           if (signinRes.ok) {
             localId = signinData.localId;
             idToken = signinData.idToken;
           } else {
             console.log(`  ❌ Failed to login to existing account to get UID: ${signinData.error.message}`);
             continue;
           }
        } else {
           throw new Error(signupData.error.message);
        }
      }

      // 2. Set user role in Firestore
      const firestoreUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${localId}`;
      const firestorePayload = {
        fields: {
          email: { stringValue: staff.email },
          name: { stringValue: staff.name },
          role: { stringValue: staff.role }
        }
      };

      const firestoreRes = await fetch(firestoreUrl, {
        method: 'PATCH',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${idToken}`
        },
        body: JSON.stringify(firestorePayload)
      });

      if (firestoreRes.ok) {
         console.log(`  ✅ Role assigned in Firestore: ${staff.role}`);
      } else {
         const err = await firestoreRes.json();
         console.log(`  ❌ Failed to set role: `, err);
      }
      console.log('');

    } catch (err) {
      console.error(`  ❌ Failed for ${staff.email}: `, err);
      console.log('');
    }
  }

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('Staff Login Credentials:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  for (const staff of STAFF_ACCOUNTS) {
    console.log(`  ${staff.role.toUpperCase().padEnd(12)} ${staff.email}  /  ${staff.password}`);
  }
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

createStaff();
