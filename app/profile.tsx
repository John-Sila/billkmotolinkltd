import React, { useEffect, useState } from "react";
import { View, Text, TextInput, Image, StatusBar, Button, StyleSheet, Alert, Modal, ActivityIndicator, TouchableOpacity } from "react-native";
import { signInWithEmailAndPassword, signOut } from "firebase/auth";
import db, { auth, subscribeToAuthChanges } from "@/assets/utilities/firebase_file";
import { doc, getDoc, query, collection, where, getDocs, updateDoc } from "firebase/firestore";
import checkAndUpdateUnpushedAmount from "@/assets/utilities/check_increment_dates";
import { useNavigation } from "@react-navigation/native";
import { Linking } from "react-native";

export default function ProfileScreen() {
  const [isLoggedIn, setIsLoggedIn] = useState<boolean | null>(null);
  const [email, setEmail] = useState<string>("");
  const [password, setPassword] = useState<string>("");
  const [userName, setUserName] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);
  const [loadingText, setLoadingText] = useState<string>("");
  // const [waiting, setWaiting] = useState<boolean>(true);

  const navigation: any = useNavigation();
  const currentYear = new Date().getFullYear();

  useEffect(() => {
    const unsubscribe = subscribeToAuthChanges(setIsLoggedIn);
    return unsubscribe;
  }, []);

  useEffect(() => {
    const user = auth.currentUser;
    if (isLoggedIn) {
      (async() => {const idToken = await user?.getIdToken(true); // 'true' forces refresh
      console.log("Refreshed ID Token:", idToken);})();
    }
  }, [isLoggedIn]);

  const handleLogin = async () => {
    if (!(email.trim().length > 4) || !(password.trim().length > 3)) {
      Alert.alert("Error", "Please enter valid credentials.");
    }
    setLoadingText("Logging you in");
    // console.log(email);
    
    try {
      if (!email) {
        Alert.alert("Error", "No email provided.");
        return;
      }
      
      setLoading(true);
      const usersCollectionRef = collection(db, "users");
      const q = query(usersCollectionRef, where("email", "==", email));
      const querySnapshot = await getDocs(q);
  
      if (querySnapshot.empty) {
          Alert.alert("Error", "User not found.");
          setLoading(false);
          return;
      }
        
        const userData = querySnapshot.docs[0].data(); // coz emails are unique
        const { is_active, is_deleted, role } = userData;
        
        if (is_deleted) {
          const deletionDate = userData.deleted_on ? new Date(userData.deleted_on.seconds * 1000) : null;
          const daysAgo = deletionDate ? Math.floor((Date.now() - deletionDate.getTime()) / (1000 * 60 * 60 * 24)) : "unknown";
          console.log(deletionDate);
          // return;
          
          
          Alert.alert("Account Deleted", `Your account has been deleted. Contact your administrator for more information.`);
          await signOut(auth);
          setLoading(false);
          return;
          
        } else if (!is_active) {
          Alert.alert("Account Deactivated", "Your account was disabled for a while. Contact a BILLK Admin.");
          await signOut(auth); // Ensure logout happens instantly
          setLoading(false);
          return;
        } else {

          try {
            
            const userCredential = await signInWithEmailAndPassword(auth, email, password);
            const userUid = userCredential.user.uid;

            
            const userDocRef = doc(db, "users", userUid);
            const userDocSnap = await getDoc(userDocRef);
            
            await checkAndUpdateUnpushedAmount();
            if (userDocSnap.exists()) {
              const userData = userDocSnap.data();
              setUserName(userData.username);
            } else {
              console.log("No such user document!");
            }
          } catch (error: any) {
            Alert.alert("Login Failed", getFirebaseAuthErrorMessage(error.message));
          } finally {
            setLoadingText("");
            setLoading(false);
          }
          
        }
  
      // console.log("User Status:", { is_active, is_deleted });
  
    } catch (error) {
        Alert.alert("Error", `An error occurred while checking email status: ${error}` );
        console.error("Error fetching user status:", error);
        setLoading(false);
    }
  
  
  };

  const getFirebaseAuthErrorMessage = (errorCode: string) => {
    const errorMessages: Record<string, string> = {
        "Firebase: Error (auth/invalid-email).": "The email address is invalid. Please check and try again.",
        "Firebase: Error (auth/user-disabled).": "This account has been disabled. Contact support for help.",
        "Firebase: Error (auth/user-not-found).": "No account found with this email. Sign up or try another email.",
        "Firebase: Error (auth/wrong-password).": "Incorrect password. Please try again.",
        "Firebase: Error (auth/email-already-in-use).": "This email is already registered. Try signing in instead.",
        "Firebase: Error (auth/weak-password).": "Password is too weak. Use at least 6 characters with numbers & symbols.",
        "Firebase: Error (auth/missing-password).": "Please enter your password.",
        "Firebase: Error (auth/missing-email).": "Please enter your email address.",
        "Firebase: Error (auth/too-many-requests).": "Too many login attempts. Please wait and try again later.",
        "Firebase: Error (auth/network-request-failed).": "Network error. Check your internet connection and try again.",
        "Firebase: Error (auth/requires-recent-login).": "You need to log in again for security reasons.",
        "Firebase: Error (auth/invalid-credential).": "Invalid credentials. Please check and try again.",
        "Firebase: Error (auth/operation-not-allowed).": "This sign-in method is not enabled. Contact support.",
        "Firebase: Error (auth/internal-error).": "An unexpected error occurred. Please try again later.",
        "Firebase: Error (auth/unverified-email).": "Please verify your email before signing in.",
    };

    return errorMessages[errorCode] || "An unknown error occurred. Please try again.";
};
  

  
  const handleLogout = async () => {
    try {
      setLoading(true);
      setLoadingText("Logging you out");
      await signOut(auth);
    } catch (error: any) {
      Alert.alert("Logout Failed", error.message);
    } finally {
      setLoadingText("");
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar
                      barStyle="light-content"
                      backgroundColor="rgb(242, 242, 242)"
                  />
      {isLoggedIn ? (
        <View style={styles.profileContainer}>
          <Text style={styles.profileHeaderText}>Hello, 🙋🏾‍♂️!</Text>
          <Text style={styles.profileText}>Your BILLK session expired. You need to login again.</Text>
          <Button title="Logout" onPress={handleLogout} />
        </View>
      ) : (
        <View style={styles.loginContainer}>
          <Image source={require('../assets/images/bml_logo.png')} style={styles.image} resizeMode="contain" />
          {/* <Text style={styles.title}>🔑 BillK Motolink LTD</Text> */}
          <TextInput
            style={styles.input}
            placeholder="Email"
            value={email}
            onChangeText={setEmail}
            keyboardType="email-address"
          />
          <TextInput
            style={styles.input}
            placeholder="Password"
            secureTextEntry
            value={password}
            onChangeText={setPassword}
          />
          <Button title="Login" onPress={handleLogin} />
          {/* <Text style={styles.ourDeclaration}>OPTIMABYTE SOFTWARES</Text> */}
          <TouchableOpacity
          style={styles.ourDeclarationOut}
            onPress={() =>
              Linking.openURL("https://wa.me/254717405109?text=`*Hello, Developer!*`\n")
            }
          >
            <Text style={styles.ourDeclaration}>OPTIMABYTE SOFTWARES © {currentYear}</Text>
          </TouchableOpacity>
        </View>
      )}

      <Modal transparent={true} visible={loading}>
          <View style={styles.modalContainer}>
          <ActivityIndicator size="large" color="green" />
          <Text style={styles.loadingText}>Running BILLK Authentication...</Text>
          </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    padding: 20,
  },
  loginContainer: {
    width: "100%",
    maxWidth: 300,
    alignItems: "center",
  },
  profileContainer: {
    alignItems: "center",
  },
  title: {
    fontSize: 22,
    fontWeight: "bold",
    marginBottom: 20,
    fontFamily: "monospace",
    textTransform: "uppercase",
  },
  input: {
    width: "100%",
    padding: 10,
    borderWidth: 1,
    borderColor: "#ccc",
    borderRadius: 5,
    marginBottom: 10,
  },
  profileHeaderText: {
    fontSize: 20,
    marginBottom: 10,
    fontWeight: "bold",
    color: "green",
  },
  profileText: {
    fontSize: 20,
    marginBottom: 10,
    textAlign: "center",
  },
  image: {
    width: '100%',
    height: 150,
    marginBottom: 20,
  },
  ourDeclarationOut: {
    marginTop: 150,
  },
  ourDeclaration: {
    position: "fixed",
    bottom: 0,
    color: "rgb(230,230,230)",
    fontWeight: 'bold',
    fontFamily: 'monospace',
    letterSpacing: 10,
    textAlign: 'center',
  },








  modalContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  loadingText: {
    marginTop: 10,
    fontSize: 16,
    color: 'green',
  },
});
