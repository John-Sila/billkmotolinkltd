import AnalyticAccessDenied from "@/assets/admin_analytics/access_denied";
import Approvals from "@/assets/admin_analytics/approvals";
import ClockOutReports from "@/assets/admin_analytics/clock_out_reports";
import DamageReports from "@/assets/admin_analytics/damage_reports";
import UserLocations from "@/assets/admin_analytics/user_locations";
import QualityControl from "@/assets/admin_analytics/qc";
import CheckIfThisUserIsStillLoggedIn from "@/assets/utilities/check_login_status";
import db, { auth } from "@/assets/utilities/firebase_file";
import { Ionicons } from "@expo/vector-icons";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { useFocusEffect } from "expo-router";
import { getAuth, signOut } from "firebase/auth";
import { collection, doc, getDoc, getDocs, query, where } from "firebase/firestore";
import { useCallback, useEffect, useState } from "react";
import { KeyboardAvoidingView, Text, View, StatusBar, ScrollView, StyleSheet, Platform, TouchableOpacity, Alert, Modal, ActivityIndicator } from "react-native";

export default function Analytics() {

  const [visibleSection, setVisibleSection] = useState<'approvals' | 'damageReports' | 'userLocation' | "clockOutReports" | "qc" | "accessDenied">('approvals');
  const [activeSection, setActiveSection] = useState<string | null>(null);
  
  const [userRole, setUserRole] = useState<string | null>(null);

  const handleSectionToggle = (section: string) => {
      setActiveSection(prevSection => (prevSection === section ? null : section));
  };

  // Function to toggle sections
  const toggleSection = (section: 'approvals' | 'damageReports' | 'userLocation'| 'clockOutReports' | 'qc' | "accessDenied" ) => {
      setVisibleSection(section);
  };

  useFocusEffect(
    useCallback( () => {
      CheckIfThisUserIsStillLoggedIn();
      fetchRole();

      
    }, [])
  )

  const fetchRole = async () => {
    // const role = await AsyncStorage.getItem("userRole");
    // console.log("role: ", role);

    const auth = getAuth();
    const user = auth.currentUser;

    if (user && user.email) {
        try {
          const q = query(
            collection(db, "users"),
            where("email", "==", user.email)
          );
  
          const querySnapshot = await getDocs(q);
          if (!querySnapshot.empty) {
            const userDoc = querySnapshot.docs[0];
            const role = userDoc.data().role;
            setUserRole(role);
            console.log("Role:", role);
          } else {
            console.log("No user found with that email.");
          }
        } catch (error) {
          console.error("Error fetching role:", error);
        }
    } else {
        console.log("No authenticated user.");
        Alert.alert('Error', 'Your account is either not authenticated or lacks enough permissions. Please log in again.');
        await signOut(auth);
    }
};

  useEffect( () => {
    if (userRole === "Regular User") {
      setActiveSection("accessDenied");
    } else if (userRole === "Admin" || userRole === "CEO") {
      setActiveSection("approvals");
    }
  }, [userRole])

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
      <StatusBar
          barStyle="light-content"
          backgroundColor="green"
      />


        {
          (userRole === "Admin" || userRole === "CEO") &&
          <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
            <View>
              <View style={styles.linkContainer}>

                <TouchableOpacity onPress={() => {toggleSection('approvals'); !(visibleSection === "approvals") && handleSectionToggle('approvals')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                    <Ionicons name="checkmark-done-circle" size={22} color="gray" {...activeSection === 'approvals' && styles.activeIcon} />
                    <Text style={[styles.linkText, activeSection === 'approvals' && styles.activeLink]}>Approvals</Text>
                </TouchableOpacity>

                <TouchableOpacity onPress={() => {toggleSection('damageReports'); !(visibleSection === "damageReports") && handleSectionToggle('damageReports')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                    <Ionicons name="warning" size={22} color="gray" {...activeSection === 'damageReports' && styles.activeIcon} />
                    <Text style={[styles.linkText, activeSection === 'damageReports' && styles.activeLink]}>Damage Reports</Text>
                </TouchableOpacity>

                {/* <TouchableOpacity onPress={() => {toggleSection('userLocation'); !(visibleSection === "userLocation") && handleSectionToggle('userLocation')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                    <Ionicons name="location" size={22} color="gray" {...activeSection === 'userLocation' && styles.activeIcon} />
                    <Text style={[styles.linkText, activeSection === 'userLocation' && styles.activeLink]}>User Location</Text>
                </TouchableOpacity> */}

                <TouchableOpacity onPress={() => {toggleSection('clockOutReports'); !(visibleSection === "clockOutReports") && handleSectionToggle('clockOutReports')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                    <Ionicons name="bookmarks" size={22} color="gray" {...activeSection === 'clockOutReports' && styles.activeIcon} />
                    <Text style={[styles.linkText, activeSection === 'clockOutReports' && styles.activeLink]}>Daily Reports</Text>
                </TouchableOpacity>

                <TouchableOpacity onPress={() => {toggleSection('qc'); !(visibleSection === "qc") && handleSectionToggle('qc')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                    <Ionicons name="analytics" size={22} color="gray" {...activeSection === 'qc' && styles.activeIcon} />
                    <Text style={[styles.linkText, activeSection === 'qc' && styles.activeLink]}>QA & C</Text>
                </TouchableOpacity>

              </View>

                {visibleSection === 'approvals' && (
                  <View style={styles.sectionContainer}>
                      {<Approvals />}
                  </View>
                )}
                
                {visibleSection === 'damageReports' && (
                  <View style={styles.sectionContainer}>
                      {<DamageReports />}
                  </View>
                )}
                
                {visibleSection === 'userLocation' && (
                  <View style={styles.sectionContainer}>
                      {<UserLocations/>}
                  </View>
                )}
                
                {visibleSection === 'clockOutReports' && (
                  <View style={styles.sectionContainer}>
                      {<ClockOutReports/>}
                  </View>
                )}
                
                {visibleSection === 'qc' && (
                  <View style={styles.sectionContainer}>
                      {<QualityControl />}
                  </View>
                )}
                
                {visibleSection === 'accessDenied' && (
                  <View style={styles.sectionContainer}>
                      {<QualityControl />}
                  </View>
                )}
            </View>

          </ScrollView>
      }
      {
        userRole === "Regular User" &&
        <View>
            <ScrollView>
              {<AnalyticAccessDenied />}

            </ScrollView>
        </View>
      }

      <Modal transparent={true} visible={userRole === null}>
          <View style={styles.modalContainer}>
              <ActivityIndicator size="large" color="rgba(255, 0, 0, 0.775)" />
              <Text style={styles.loadingText}>Authenticating Access...</Text>
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
      padding: 0,
  },
  linkContainer: {
      flexDirection: 'row',
      justifyContent: 'space-around',
      backgroundColor: '#fff',
      paddingBottom: 10,
      paddingTop: 10,
      position: 'sticky',
      top: 0,
  },
  linkText: {
      fontSize: 10,
      color: 'gray',
      fontWeight: 'bold',
  },
  activeLink: {
      color: 'green',
  },
  activeIcon: {
      color: 'green',
  },
  sectionContainer: {
      marginBottom: 20,
      padding: 20,
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
