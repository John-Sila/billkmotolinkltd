
import React, { useCallback, useEffect, useRef, useState } from "react";
import { View, StyleSheet, Alert, Text, StatusBar, KeyboardAvoidingView, ScrollView, Platform, RefreshControl, Modal, ActivityIndicator, TextInput, } from "react-native";
import MapView, { Marker, MapViewProps } from "react-native-maps";
import * as Location from "expo-location";
import * as TaskManager from 'expo-task-manager';
import { Redirect, useFocusEffect } from "expo-router";
import * as Device from 'expo-device';
// import db, { auth } from "@/utilities/firebase";
import { doc, getDoc, setDoc, Timestamp, updateDoc } from "firebase/firestore";
import db, { auth } from "@/assets/utilities/firebase_file";
import { Magnetometer } from "expo-sensors";
import Button1 from "@/assets/utilities/button1";
import { EmailAuthProvider, getAuth, reauthenticateWithCredential, signOut, updatePassword } from "firebase/auth";
import CheckIfThisUserIsStillLoggedIn from "@/assets/utilities/check_login_status";
import checkAndUpdateUnpushedAmount from "@/assets/utilities/check_increment_dates";
import { Ionicons } from "@expo/vector-icons";

interface UserData {
  unpushed_amount?: number;
  amount_pending_approval?: number;
}
const formatCurrency = (amount: number) => {
  return new Intl.NumberFormat('en-KE', {
    style: 'currency',
    currency: 'KES',
    minimumFractionDigits: 0
  }).format(amount);
};

export default function Index() {
  const [location, setLocation] = useState<Location.LocationObjectCoords | null>(null);
  const [geocodeLoc, setGeocodeLoc] = useState<string | null>(null);
  const [unpushedAmount, setUnpushedAmount] = useState<number>(0);
  const [unapprovedAmount, setUnapprovedAmount] = useState<number>(0);
  const [heading, setHeading] = useState(0); // Device orientation in degrees
  const mapRef = useRef<MapView | null>(null);
  const [loadingAction, setLoadingAction] = useState("Loading"); //
  const [newAmountToPush, setNewAmountToPush] = useState<string>("");
  const [userSpeed, setUserSpeed] = useState<number>(0);
  const [locationBg, setLocationBg] = useState<{ latitude: number; longitude: number; accuracy: number } | null>(null);
  const [lastUpdateTime, setLastUpdateTime] = useState<number>(0);
  const [weather, setWeather] = useState<any>(null);

  const [currentPassword, setCurrentPassword] = useState<string>("");
  const [newPassword, setNewPassword] = useState<string>("");
  const [showPasswordsModal, setShowPasswordsModal] = useState(false);

  const [loading, setLoading] = useState<boolean>(true);
  const [refreshing, setRefreshing] = useState<boolean>(false);


  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);

  // create a background task manager that uploads location information

  const LOCATION_TASK_NAME = "background-location-task";

  // Define Background Location Task
  TaskManager.defineTask(LOCATION_TASK_NAME, async ({ data, error }: { data?: { locations: Location.LocationObject[] }; error?: any }) => {
    if (error) {
      console.error("Background location task error:", error);
      return;
    }
  
    if (!data || !data.locations || data.locations.length === 0) {
      console.warn("No location data received.");
      return;
    }
  
    const latestLocation = data.locations[data.locations.length - 1];
  
    if (!latestLocation || !latestLocation.coords) {
      console.warn("Invalid location data.");
      return;
    }
  
    // Process the location data
    setLocationBg({
      latitude: latestLocation.coords.latitude,
      longitude: latestLocation.coords.longitude,
      accuracy: latestLocation.coords.accuracy ? latestLocation.coords.accuracy : 0,
    });
  
    setUserSpeed(latestLocation.coords.speed ? latestLocation.coords.speed : 0);
  
    const locationData = {
      latitude: latestLocation.coords.latitude,
      longitude: latestLocation.coords.longitude,
      accuracy: latestLocation.coords.accuracy,
      timestamp: Timestamp.now(),
      lastSpeed: latestLocation.coords.speed,
      heading: latestLocation.coords.heading || 0,
    };
  
    try {
      const userUid = auth.currentUser?.uid;
      if (!userUid) {
        console.warn("No authenticated user found.");
        return;
      }


  
      const userRef = doc(db, "users", userUid);

      const userSnap = await getDoc(userRef);

      if (userSnap.exists()) {
        const userData = userSnap.data();
        const lastTimestamp = userData?.location?.timestamp;

        if (lastTimestamp?.seconds) {
          const lastUpdateTime = lastTimestamp.seconds * 1000; // Convert to ms
          const currentTime = Date.now();
          const minutesPassed = (currentTime - lastUpdateTime) / (1000 * 60);

          if (minutesPassed < 3) {
            console.log(`Skipping update: Only ${minutesPassed.toFixed(1)} minutes since last update.`);
            return;
          }
        }
      }

      await setDoc(
        userRef,
        {
          location_update_time: new Date().toISOString(),
          location: {
            latitude: locationData.latitude,
            longitude: locationData.longitude,
            accuracy: locationData.accuracy,
            timestamp: locationData.timestamp,
            lastSpeed: locationData.lastSpeed,
            heading: convertMvtDirection(locationData.heading),
          },
        },
        { merge: true }
      );
      console.log("Location updated to database.");
    } catch (error) {
      console.error("Error uploading location:", error);
    }
  
    console.log("Location updated successfully");
  });

  useEffect(() => {
    let subscription: Location.LocationSubscription | null = null;

    (async () => {
      let { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== "granted") {
        Alert.alert("Permission Denied", "Allow location access to use this feature.");
        return;
      }

      // Start tracking location updates
      subscription = await Location.watchPositionAsync(
        { accuracy: Location.Accuracy.Highest, timeInterval: 5000, distanceInterval: 5 },
        (currentLocation) => {
          setLocation(currentLocation.coords); // Updates location in real-time
        }
      );

      
      
    })();

    /// track location changes
    (async () => {
      await startLocationTracking();
      await getUserLocation();
    })();
    
    fetchData();


    return () => {
      if (subscription) {
        subscription.remove(); // Cleanup on unmount
      }
    };
  }, []);

  useEffect(() => {
    // Subscribe to magnetometer updates
    const subscription = Magnetometer.addListener((data) => {
      const angle = calculateHeading(data);
      setHeading(angle);
    });

    Magnetometer.setUpdateInterval(100); // Update every 100 milliseconds

    return () => subscription.remove(); // Clean up subscription on unmount
  }, []);

  useEffect(() => {
    // Rotate the map instantly when heading changes
    if (mapRef.current) {
      mapRef.current.animateCamera(
        {
          heading: heading,
          pitch: 0,
          zoom: 15,
        },
        { duration: 100 }
      );
    }
  }, [heading]);

  useFocusEffect(
      useCallback(() => {
        CheckIfThisUserIsStillLoggedIn();
        checkAndUpdateUnpushedAmount();
        getUserLocation();
        fetchData();
      }, [])
  );

  useEffect( () => {
      fetchData();
  }, [])
  
  async function startLocationTracking() {
      const { status } = await Location.requestBackgroundPermissionsAsync();
    
      if (status !== "granted") {
        Alert.alert(
          "Alert!",
          "BILLK MOTOLINK LTD needs this permission. Allow permission for 'ALWAYS' access."
        );
        return;
      }
    
      const hasStarted = await Location.hasStartedLocationUpdatesAsync(LOCATION_TASK_NAME);
      if (!hasStarted) {
        await Location.startLocationUpdatesAsync(LOCATION_TASK_NAME, {
            accuracy: Location.Accuracy.High,
            timeInterval: 2 * 60 * 1000, // Update every 2 minutes (ignored in background)
            distanceInterval: 100, // Update when moved by 100 meters
            showsBackgroundLocationIndicator: true,
        });
    
        console.log("Background location tracking started.");
      } else {
        console.log("Background location tracking is already running.");
      }
  }
  
  // Convert heading degrees to movement direction
  const convertMvtDirection = (degree: number) => {
    if (degree >= 337.5 || degree < 22.5) return "North";
    if (degree >= 22.5 && degree < 67.5) return "North-East";
    if (degree >= 67.5 && degree < 112.5) return "East";
    if (degree >= 112.5 && degree < 157.5) return "South-East";
    if (degree >= 157.5 && degree < 202.5) return "South";
    if (degree >= 202.5 && degree < 247.5) return "South-West";
    if (degree >= 247.5 && degree < 292.5) return "West";
    if (degree >= 292.5 && degree < 337.5) return "North-West";
    return "Stationary";
  };

  



  async function getUserLocation() {
    let { status } = await Location.requestForegroundPermissionsAsync();
    if (status !== 'granted') {
      console.log('Permission to access location was denied');
      return;
    }
  
    let location = await Location.getCurrentPositionAsync({});
    let reverseGeocode = await Location.reverseGeocodeAsync({
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
    });
    
    if (reverseGeocode.length > 0) {
      let place = reverseGeocode[0];
      setGeocodeLoc(`${place.city}, ${place.region}, ${place.country}`);
    }

    // try {
    //   const apiKey = 'cf42a7ef65074716aa5120347250303';
    //   const weatherUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${location.coords.latitude}&lon=${location.coords.longitude}&appid=${apiKey}&units=metric`;
  
    //   const response = await fetch(weatherUrl);
    //   const data = await response.json();
    //   console.log(data);
      
    //   setWeather(data);
    // } catch (error) {
    //   Alert.alert("Error", `Couldn't fetch weather data: ${error}`)
    // }
  }


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

     























  const onRefresh = async () => {
    setRefreshing(true);
    setLoadingAction("Refreshing");
  
    try {
      await Promise.all([fetchData(),]);
    } catch (error) {
      console.error("Error refreshing data:", error);
    } finally {
      setRefreshing(false); // Ensures it stops refreshing after both functions complete
    }
  };
  



  let lastHeading = 0;
  const ALPHA = 0.1; // Smoothing factor (0 = full smoothing, 1 = no smoothing)

  const smoothHeading = (newHeading: number) => {
    lastHeading = ALPHA * newHeading + (1 - ALPHA) * lastHeading;
    return lastHeading;
  };
   // Function to calculate the heading (in degrees) from magnetometer data
   const calculateHeading = (data: any) => {
    let { x, y } = data;
    let angle = Math.atan2(y, x) * (180 / Math.PI);
    angle = (angle + 260) % 360; // Add 90 degrees offset
    return smoothHeading(angle);
  };






  const fetchData = async () => {
    const user = auth.currentUser;
    const userDocRef = doc(db, `users/${user?.uid}`);
    try {
      if (loadingAction !== "Refreshing") {
        setLoading(true);
      }
      const docSnap = await getDoc(userDocRef);
      if (docSnap.exists()) {
        const data = docSnap.data() as UserData; // type casting
        setUnpushedAmount(data.unpushed_amount ?? 0); // default to 0
        setUnapprovedAmount(data.amount_pending_approval ?? 0);
      } else {
        console.log("No such document!");
      }
    } catch (error) {
      Alert.alert("Error", "Failed to fetch data");
      console.error("Firestore error:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleRequestApproval = async () => {
    const currentUser = auth.currentUser;  // Get the current logged-in user
    if (!currentUser) {
      Alert.alert("No user is logged in.");
      return;
    }
    setLoading(true);
  
    const amountToApprove: number = parseFloat(newAmountToPush); // Convert input to a number
    if (!amountToApprove || amountToApprove <= 0) {
      Alert.alert("Error", "Please enter a valid amount.");
      setLoading(false);
      return;
    }
  
    try {
      const userRef = doc(db, "users", currentUser.uid); // Reference to the current user's Firestore document
      const userSnapshot = await getDoc(userRef);
  
      if (userSnapshot.exists()) {
        const userData = userSnapshot.data();
        const currentUnpushedAmount = userData.unpushed_amount || 0;
        const currentPendingApproval = userData.amount_pending_approval || 0;
  
        // if (amountToApprove > currentUnpushedAmount) {
        //   Alert.alert("Error", "You cannot approve more than the unpushed amount.");
        //   return;
        // }

        // Update Firestore values
        await updateDoc(userRef, {
          amount_pending_approval: currentPendingApproval + amountToApprove,
          unpushed_amount: currentUnpushedAmount - amountToApprove,
          filterable_date: new Date().toISOString(),
        });
  
        Alert.alert("Success", "Approval request submitted successfully.");
        setNewAmountToPush(""); // Clear the input

      } else {
        Alert.alert("Error", "User data not found.");
      }
    } catch (error) {
      console.error("Error requesting approval:", error);
      Alert.alert("Error", "Something went wrong. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const ChangeMyPassword = () => {
    const auth = getAuth();
    const user = auth.currentUser;

    if (currentPassword === newPassword) {
      Alert.alert("Action Invalid", "Your passwords are same. Enter a different new password.");
      return;
    }
    setLoading(true);

    if (user) {
      const credential = EmailAuthProvider.credential(
        user.email!,
        currentPassword
      );

      reauthenticateWithCredential(user, credential)
        .then(() => {
          return updatePassword(user, newPassword);
        })
        .then( async () => {
          console.log("Password updated after reauth!");
          Alert.alert("Success", "Password updated. Log in again using your new password.");
          await signOut(auth);
        })
        .catch((error: any) => {
          Alert.alert("Password Change Failed", getFirebaseAuthErrorMessage(error.message));
        }).finally(() => {
          setCurrentPassword("");
          setNewPassword("");
          setShowPasswordsModal(false);
          setLoading(false);
        });
      }
      setLoading(false);
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
      <StatusBar
                      barStyle="light-content"
                      backgroundColor="green"
                  />
        
      <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled"
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={["green"]} />
          }
      >
        <Text style={styles.IndexHeader}>My Account</Text>
        <Text style={styles.locationText}>{geocodeLoc}</Text>

        <View style={styles.innerContainer} >
            <Text style={styles.hometext}>Unpushed Amount: <Text style={styles.unpushedAText}>{formatCurrency(Math.ceil(unpushedAmount))}.00</Text></Text>
            <Text style={styles.hometext}>Amount Awaiting Approval: <Text style={styles.pendingApprovalAText}>{formatCurrency(Math.ceil(unapprovedAmount))}.00</Text></Text>
          
        </View>

        <View style={styles.evenInnerContainer3}>
            <Text style={styles.actualRegularText3}>● The unpushed amount is all income not recorded on active days</Text>
            <Text style={styles.actualRegularText3}>● After pushing the amount, await approval by an Admin.</Text>
        </View>

        <View style={styles.evenInnerContainer4}>
            <Text style={styles.actualRegularText3}>Request for Income Approval.</Text>
            <TextInput
                placeholder="Amount to approve (Numbers only)"
                value={newAmountToPush}
                onChangeText={setNewAmountToPush}
                style={styles.input}
                autoCapitalize="none"
                keyboardType="numeric"
            />
            <Button1 title={  `Request ${newAmountToPush ? "Approval for " + formatCurrency(Math.ceil(parseFloat(newAmountToPush))) + ".00" : ""}`  } bgColor='rgba(255, 165, 0, 0.775)' onPress={handleRequestApproval} />
        </View>

        <View style={styles.accountSettings}>
            <Text style={styles.AcSText}>Account Settings</Text>
            <Button1 title={`Change Password`} bgColor='green' onPress={() => setShowPasswordsModal(true)} />

        </View>


      </ScrollView>


      <Modal
          visible={showPasswordsModal}
          transparent={true}
          animationType="slide"
          onRequestClose={() => {setShowPasswordsModal(false); setCurrentPassword(""); setNewPassword("");}}
      >
          <View style={styles.modalContainer}>
  <View style={styles.modalContent}>
    
    <View style={styles.alignContainer1}>
      <View style={styles.passwordContainer}>
        <TextInput
          placeholder="Old Password"
          value={currentPassword}
          onChangeText={setCurrentPassword}
          secureTextEntry={!showCurrentPassword}
          style={styles.input}
        />
        <Ionicons
          name={showCurrentPassword ? 'eye-off' : 'eye'}
          size={24}
          color="gray"
          onPress={() => setShowCurrentPassword(!showCurrentPassword)}
          style={styles.eyeIcon}
        />
      </View>
    </View>

    <View style={styles.alignContainer1}>
      <View style={styles.passwordContainer}>
        <TextInput
          placeholder="New Password"
          value={newPassword}
          onChangeText={setNewPassword}
          secureTextEntry={!showNewPassword}
          style={styles.input}
        />
        <Ionicons
          name={showNewPassword ? 'eye-off' : 'eye'}
          size={24}
          color="gray"
          onPress={() => setShowNewPassword(!showNewPassword)}
          style={styles.eyeIcon}
        />
      </View>
    </View>

    <View style={styles.alignContainer1}>
      <Button1
        title={`Cancel`}
        bgColor="red"
        onPress={() => {
          setShowPasswordsModal(false);
          setCurrentPassword('');
          setNewPassword('');
        }}
      />
      <Button1
        title={`Change Password`}
        bgColor="rgba(255, 165, 0, 0.775)"
        onPress={ChangeMyPassword}
      />
    </View>
  </View>
</View>
      </Modal>



      <Modal transparent={true} visible={loading}>
          <View style={styles.modalContainer}>
              <ActivityIndicator size="large" color="rgba(255, 165, 0, 0.775)" />
              <Text style={styles.loadingText}>Please hold on...</Text>
          </View>
      </Modal>

    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
keyboardView: {
  flex: 1,
},
scrollContainer: {
  paddingBottom: 50,
},
mapContainer: {
  width: "100%",
  height: "75%",
},
map: {
  width: "100%",
  height: "100%",
},
innerContainer: {
  borderRadius: 0,
  elevation: 0, // android shadow
  padding: 20,
  marginTop: 0,
  backgroundColor: 'rgba(255, 165, 0, 0.075)',
},
IndexHeader: {
  color: 'green',
  fontSize: 25,
  fontWeight: 'bold',
  textAlign: 'center',
  padding: 15,
  fontFamily: 'monospace',
  backgroundColor: "rgba(0, 128, 0, 0.075)",
},
locationText: {
  fontSize: 12,
  fontWeight: 'bold',
  fontFamily: 'monospace',
  backgroundColor: 'rgba(255, 165, 0, 0.075)',
  color: 'rgba(128, 0, 0, 0.175)',
  padding: 10,
},
hometext: {
  fontSize: 18,
  fontWeight: 'bold',
},
unpushedAText: {
  color: 'red',
  fontSize: 24,
  fontFamily: 'monospace',
},
pendingApprovalAText: {
  color: 'green',
  fontSize: 24,
  fontFamily: 'monospace',
},

passwordContainer: {
  flexDirection: 'row',
  alignItems: 'center',
  position: 'relative',
},
eyeIcon: {
  position: 'absolute',
  right: 10,
},


evenInnerContainer3: {
  borderRadius: 10,
  shadowColor: 'rgb(200, 200, 200)',
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: 0.2,
  shadowRadius: 5,
  elevation: 0,
  padding: 10,
  backgroundColor: 'rgba(255, 165, 0, 0.075)',
},
evenInnerContainer4: {
  borderRadius: 10,
  shadowColor: 'rgb(200, 200, 200)',
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: 0.2,
  shadowRadius: 5,
  elevation: 0,
  padding: 20,
  marginTop: 20,
  backgroundColor: "rgba(0, 128, 0, 0.075)",
},
actualRegularText3: {
  fontSize: 18,
  fontWeight: "bold",
  color: 'rgba(255, 165, 0, 0.775)',
},
input: {
  height: 50,
  borderColor: 'rgba(0, 128, 0, 0.175)',
  borderWidth: 1,
  paddingHorizontal: 8,
  borderRadius: 10,
  backgroundColor: '#fff',
  marginVertical: 20,
  width: '100%',
  paddingRight: 40,
},


accountSettings: {
  padding: 20,
},
AcSText: {
  fontSize: 21,
  color: 'green',
  fontWeight: 'bold',
  textAlign: 'center',
  padding: 15,
  fontFamily: 'monospace',
},







alignContainer1: {
  display: 'flex',
  flexDirection: 'row',
  justifyContent: 'space-between',
  paddingRight: 10,
},
modalContent: {
  width: '80%',
  padding: 20,
  backgroundColor: 'rgba(240, 240, 240, 0.8)',
  borderRadius: 30,
},
modalTitle: {
  textAlign: 'center',
  fontSize: 18,
  fontWeight: 'thin',
  marginBottom: 15,
},



  modalContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.8)',
  },
  loadingText: {
    marginTop: 10,
    fontSize: 16,
    color: '#fff',
  },
});




























