import db, { auth, getStoredUser, subscribeToAuthChanges } from "@/assets/utilities/firebase_file";
import { Ionicons } from "@expo/vector-icons";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Tabs } from "expo-router";
import { doc, getDoc } from "firebase/firestore";
import { useEffect, useState } from "react";
import { TouchableOpacity, TouchableOpacityProps, Vibration } from "react-native";

export default function TabLayout() {
  const [isLoggedIn, setIsLoggedIn] = useState<boolean | null>(null);
  const [userRole, setUserRole] = useState<string | null>(null);
  const [tabs, setTabs] = useState<any>([]);

  useEffect(() => {
    // Check stored user session on app load
    getStoredUser().then((user: any) => {
      setIsLoggedIn(!!user);
    });



    // Listen for real-time authentication changes
    const unsubscribe = subscribeToAuthChanges(setIsLoggedIn);

    return unsubscribe; // Cleanup on unmount
  }, []);

  useEffect(() => {
    const fetchRole = async () => {
      const role = await AsyncStorage.getItem("userRole");
      console.log("role: ", role);
      
      setUserRole(role);
    };
    fetchRole();
  }, []);

  // useEffect(() => {
  //   const checkUserStatus = async () => {
  //     const user = await getStoredUser(); // Fetch user session
  
  //     if (user) {
  //       const userDocRef = doc(db, "users", user.uid);
  //       const userDocSnap = await getDoc(userDocRef);
  
  //       if (userDocSnap.exists()) {
  //         const userData = userDocSnap.data();
  
  //         if (userData.is_deleted) {
  //           const deletionDate = userData.deletion_date ? new Date(userData.deletion_date.seconds * 1000) : null;
  //           const daysAgo = deletionDate ? Math.floor((Date.now() - deletionDate.getTime()) / (1000 * 60 * 60 * 24)) : "unknown";
  
  //           Alert.alert("Account Deleted", `Your account was deleted ${daysAgo} days ago.`);
  //           await signOut(auth);
  //           setIsLoggedIn(false);
  //           return;
  //         }
  
  //         if (!userData.is_active) {
  //           Alert.alert("Account Deactivated", "Your account has been deactivated.");
  //           await signOut(auth);
  //           setIsLoggedIn(false);
  //           return;
  //         }
  
  //         // If user is valid, set isLoggedIn to true
  //         setIsLoggedIn(true);
  //       } else {
  //         console.log("No user data found.");
  //         setIsLoggedIn(false);
  //       }
  //     } else {
  //       setIsLoggedIn(false);
  //     }
  //   };
  
  //   checkUserStatus();
  
  //   // Listen for authentication changes
  //   const unsubscribe = subscribeToAuthChanges(async (user) => {
  //     if (user) {
  //       await checkUserStatus(); // Ensure we verify user status on auth change
  //     } else {
  //       setIsLoggedIn(false);
  //     }
  //   });
  
  //   return unsubscribe; // Cleanup on unmount
  // }, []);
  

  useEffect(() => {
    if (userRole === "Regular User") {
      const Tabs = ['Home', 'ReportingScreen', 'Clock Out']
      setTabs(Tabs);
    } else if (userRole === "Admin" || userRole === "CEO") {
      const Tabs = ['Home', 'ReportingScreen', 'Clock Out', 'Analytics', 'Admin Panel']
      setTabs(Tabs);
    }
  }, [userRole])

  return (


    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: "green",
        tabBarStyle: { backgroundColor: "white" },
      }}
    >

      {/* <Tabs.Screen
        name="index"
        options={{
          title: "Home",
          tabBarIcon: ({ color }) => <Ionicons name="home" size={28} color={color} />,
        }}
        redirect = {!isLoggedIn}
      /> */}

      
      <Tabs.Screen
        name="index"
        options={{
          title: "Home",
          tabBarIcon: ({ color }) => <Ionicons name="home" size={28} color={color} />,
          tabBarButton: (props) => (
            <TouchableOpacity
              {...(props as TouchableOpacityProps)}
              onPress={(event) => {
                Vibration.vibrate(50); // Vibrate for 50ms
                props.onPress?.(event);
              }}
            />
          ),
        }}
        redirect={!isLoggedIn}
      />



      
    <Tabs.Screen
          name="reports"
          options={{
            title: "Reports",
            tabBarIcon: ({ color }) => <Ionicons name="document-text" size={28} color={color} />,
            tabBarButton: (props) => (
              <TouchableOpacity
                {...(props as TouchableOpacityProps)}
                onPress={(event) => {
                  Vibration.vibrate(50); // Vibrate for 50ms
                  props.onPress?.(event);
                }}
              />
            ),
          }}
          redirect={!isLoggedIn}
      />



      {/* <Tabs.Screen
        name="reports"
        options={{
          title: "Reports",
          tabBarIcon: ({ color }) => <Ionicons name="document-text" size={28} color={color} />,
        }}
        redirect = {!isLoggedIn}
      /> */}

      {/* <Tabs.Screen
        name="profile"
        options={{
          title: "Profile",
          tabBarIcon: ({ color }) => <Ionicons name="person" size={28} color={color} />,
        }}
        redirect = {!!isLoggedIn}
      /> */}

      {/* <Tabs.Screen
        name="clock_out"
        options={{
          title: "Clock Out",
          tabBarIcon: ({ color }) => <Ionicons name="sunny" size={28} color={color} />,
        }}
        redirect = {!isLoggedIn}
      /> */}

      <Tabs.Screen
        name="profile"
        options={{
          title: "Profile",
          tabBarIcon: ({ color }) => <Ionicons name="person" size={28} color={color} />,
          tabBarButton: (props) => (
            <TouchableOpacity
              {...(props as TouchableOpacityProps)}
              onPress={(event) => {
                Vibration.vibrate(50); // Vibrate for 50ms
                props.onPress?.(event);
              }}
            />
          ),
        }}
        redirect={!!isLoggedIn}
      />



      {/* <Tabs.Screen
        name="profile"
        options={{
          title: "Profile",
          tabBarIcon: ({ color }) => <Ionicons name="person" size={28} color={color} />,
          tabBarButton: (props) => (
            <TouchableOpacity
              {...(props as TouchableOpacityProps)}
              onPress={(event) => {
                Vibration.vibrate(50); // Vibrate for 50ms
                props.onPress?.(event);
              }}
            />
          ),
        }}
        redirect={!isLoggedIn}
      /> */}




      <Tabs.Screen
        name="clock_out"
        options={{
          title: "Clock Out",
          tabBarIcon: ({ color }) => <Ionicons name="sunny" size={28} color={color} />,
          tabBarButton: (props) => (
            <TouchableOpacity
              {...(props as TouchableOpacityProps)}
              onPress={(event) => {
                Vibration.vibrate(50); // Vibrate for 50ms
                props.onPress?.(event);
              }}
            />
          ),
        }}
        redirect={!isLoggedIn}
      />

      <Tabs.Screen
        name="analytics"
        options={{
          title: "Analytics",
          tabBarIcon: ({ color }) => <Ionicons name="bar-chart" size={28} color={color} />,
          tabBarButton: (props) => (
            <TouchableOpacity
              {...(props as TouchableOpacityProps)}
              onPress={(event) => {
                Vibration.vibrate(50); // Vibrate for 50ms
                props.onPress?.(event);
              }}
            />
          ),
        }}
        redirect={!isLoggedIn}
      />


      <Tabs.Screen
        name="admin_panel"
        options={{
          title: "Admin Panel",
          tabBarIcon: ({ color }) => <Ionicons name="shield-checkmark" size={28} color={color} />,
          tabBarButton: (props) => (
            <TouchableOpacity
              {...(props as TouchableOpacityProps)}
              onPress={(event) => {
                Vibration.vibrate(50); // Vibrate for 50ms
                props.onPress?.(event);
              }}
            />
          ),
        }}
        redirect={!isLoggedIn}
      />

      {/* <Tabs.Screen
        name="analytics"
        options={{
          title: "Analytics",
          tabBarIcon: ({ color }) => <Ionicons name="bar-chart" size={28} color={color} />,
        }}
        redirect = {!isLoggedIn}
      /> */}

      {/* <Tabs.Screen
        name="admin_panel"
        options={{
          title: "Admin Panel",
          tabBarIcon: ({ color }) => <Ionicons name="shield-checkmark" size={28} color={color} />,
        }}
        redirect = {!isLoggedIn}
      /> */}

    </Tabs>
  )
}