import { initializeApp, getApps, getApp } from "firebase/app";
import { initializeAuth, getReactNativePersistence, onAuthStateChanged, User } from "firebase/auth";
import { doc, getDoc, getFirestore } from "firebase/firestore";
import AsyncStorage from "@react-native-async-storage/async-storage";

const firebaseConfig = {

  // TODO? This is the actual original configuration 
  apiKey: "AIzaSyAjphBq93aJEprvYkE9TzupWGH-2l8iOV0",
  authDomain: "billkaymotors.firebaseapp.com",
  projectId: "billkaymotors",
  storageBucket: "billkaymotors.firebasestorage.app",
  messagingSenderId: "563358146944",
  appId: "1:563358146944:web:cc27c13562e79352926165",
  measurementId: "G-VG5F70K7QM"

  // TODO? DUMMY: Picked from retro
  // apiKey: "AIzaSyB-opll1P-81cOoc7oQUQ7G5QUSK5FhfrA",
  // authDomain: "retro-bf312.firebaseapp.com",
  // databaseURL: "https://retro-bf312-default-rtdb.firebaseio.com",
  // projectId: "retro-bf312",
  // storageBucket: "retro-bf312.appspot.com",
  // messagingSenderId: "319056909364",
  // appId: "1:319056909364:web:f2215ade4b825b8fe56661",
  // measurementId: "G-NT5D2WTQ8T"

};

const firebase_app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApp();
const auth = initializeAuth(firebase_app, {
  persistence: getReactNativePersistence(AsyncStorage),
});

const db = getFirestore(firebase_app);

const storeUserSession = async (user: User | null) => {
  if (user) {
    await AsyncStorage.setItem("user", JSON.stringify(user));
  } else {
    await AsyncStorage.removeItem("user");
  }
};

const getStoredUser = async () => {
  const userData = await AsyncStorage.getItem("user");
  return userData ? JSON.parse(userData) : null;
};
const subscribeToAuthChanges = (setIsLoggedIn: (state: boolean) => void) => {
  return onAuthStateChanged(auth, async (user) => {
    if (user) {
      setIsLoggedIn(true);
      const userDocRef = doc(db, "users", user.uid);
      const userDocSnap = await getDoc(userDocRef);

      if (userDocSnap.exists()) {
        const userData = userDocSnap.data();
        const role = userData.role || "Regular User";
        
        try {
          await AsyncStorage.setItem("userRole", role);
        } catch (error) {
          console.error("Error saving user role:", error);
        }
      }
    } else {
      setIsLoggedIn(false);

      await AsyncStorage.removeItem("userRole");
    }
  });
};

export { firebase_app, auth, getStoredUser, subscribeToAuthChanges };
export default db;