import { signOut } from "firebase/auth";
import { Alert } from "react-native";
import db, { auth } from "./firebase_file";
import { doc, getDoc } from "firebase/firestore";

const CheckIfThisUserIsStillLoggedIn = async () => {
    const uid = auth.currentUser?.uid;
    if (uid) {
      try {
        const userDoc = await getDoc(doc(db, 'users', uid));
        if (userDoc.exists()) {
          const userData = userDoc.data();
          // console.log(userData.is_deleted == undefined);
          // console.log("checked login status");
          
          
          if ((userData.is_deleted !== undefined && userData.is_deleted !== null && userData.is_deleted) || userData.is_active !== undefined && userData.is_active !== null && !userData.is_active) {
            Alert.alert("BILLK MOTOLINK LTD", 'Session has insufficient permissions. Please log in again and if this issue persists, contact your administrator.');
            await signOut(auth);
          }
        } else {
          console.log('User document not found.');
          Alert.alert("BILLK MOTOLINK LTD", 'You have incomplete records. Please consult an Administrator for a new account.');
          await signOut(auth);
        }
      } catch (err: any) {
        console.error('Error checking user status:', err.message);
        Alert.alert('Error checking user status:', err.message);
      }
    } else {
      Alert.alert("Sorry", "You will need to login again. If this problem persists, contact an Administrator")
      await signOut(auth);
    }

  }

  export default CheckIfThisUserIsStillLoggedIn;