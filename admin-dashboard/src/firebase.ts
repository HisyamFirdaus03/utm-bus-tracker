import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

// Paste values from Firebase Console → Project Settings → Your apps →
// (web app) → SDK setup and configuration → "Config".
// Or set them in a .env.local file using the VITE_FIREBASE_* keys below.
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
