import { Ionicons } from "@expo/vector-icons";
import { useCallback, useEffect, useState } from "react";
import { KeyboardAvoidingView, StatusBar, Platform, Text, View, ScrollView, ActivityIndicator, StyleSheet, Modal, TouchableOpacity, TextInput, Alert, Image } from "react-native";
import * as ImagePicker from 'expo-image-picker';
import Button1 from "@/assets/utilities/button1";
import { getStorage, ref, uploadBytes, getDownloadURL, uploadBytesResumable } from "firebase/storage";
import * as ImageManipulator from "expo-image-manipulator";
import { createUserWithEmailAndPassword, getAuth, signInWithEmailAndPassword, signOut } from "firebase/auth";
import db, { auth } from "@/assets/utilities/firebase_file";
import { addDoc, collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where } from "firebase/firestore";
import axios from 'axios';
import { useFocusEffect } from "expo-router";
import ReactivateUser from "@/assets/admin_actions/reactivate_user";
import DeleteUser from "@/assets/admin_actions/delete_user";
import CreateUser from "@/assets/admin_actions/add_user";
import DeactivateUser from "@/assets/admin_actions/deactivate_user";
import AddBike from "@/assets/admin_actions/add_bike";
import DeleteBike from "@/assets/admin_actions/delete_bike";
import CheckIfThisUserIsStillLoggedIn from "@/assets/utilities/check_login_status";
import AsyncStorage from "@react-native-async-storage/async-storage";
import AnalyticAccessDenied from "@/assets/admin_analytics/access_denied";
import checkAndUpdateUnpushedAmount from "@/assets/utilities/check_increment_dates";

const storage = getStorage();

export default function AdminPanel() {
    const [visibleSection, setVisibleSection] = useState<'none' | 'addUser' | 'deactivateUser' | 'reactivateUser' | 'deleteUser' | 'addBike' | 'deleteBike' | "accessDenied">('addUser');
    const [activeSection, setActiveSection] = useState<string | null>(null);
    
    const [userRole, setUserRole] = useState<string | null>(null);

    const handleSectionToggle = (section: string) => {
        setActiveSection(prevSection => (prevSection === section ? null : section));
    };

    // Function to toggle sections
    const toggleSection = (section: 'addUser' | 'deleteUser' | 'deactivateUser' | 'reactivateUser' | 'addBike' | 'deleteBike' | "accessDenied" | 'none') => {
        setVisibleSection(section);
    };

    useFocusEffect(
        useCallback( () => {
            CheckIfThisUserIsStillLoggedIn();
            checkAndUpdateUnpushedAmount();
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
        setActiveSection("addUser");
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

                    {/* Links to toggle sections */}
                    <View style={styles.linkContainer}>

                        <TouchableOpacity onPress={() => {toggleSection('addUser'); !(visibleSection === "addUser") && handleSectionToggle('addUser')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                            <Ionicons name="finger-print" size={22} color="gray" {...activeSection === 'addUser' && styles.activeIcon} />
                            <Text style={[styles.linkText, activeSection === 'addUser' && styles.activeLink]}>Add User</Text>
                        </TouchableOpacity>

                        <TouchableOpacity onPress={() => {toggleSection('deactivateUser'); !(visibleSection === "deactivateUser") && handleSectionToggle('deactivateUser')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                            <Ionicons name="exit" size={22} color="gray" {...activeSection === 'deactivateUser' && styles.activeIcon} />
                            <Text style={[styles.linkText, activeSection === 'deactivateUser' && styles.activeLink]}>Deactivate User</Text>
                        </TouchableOpacity>

                        <TouchableOpacity onPress={() => {toggleSection('reactivateUser'); !(visibleSection === "reactivateUser") && handleSectionToggle('reactivateUser')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                            <Ionicons name="enter" size={22} color="gray" {...activeSection === 'reactivateUser' && styles.activeIcon} />
                            <Text style={[styles.linkText, activeSection === 'reactivateUser' && styles.activeLink]}>Reactivate User</Text>
                        </TouchableOpacity>

                        <TouchableOpacity onPress={() => {toggleSection('deleteUser'); !(visibleSection === "deleteUser") && handleSectionToggle('deleteUser')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                            <Ionicons name="footsteps" size={22} color="gray" {...activeSection === 'deleteUser' && styles.activeIcon} />
                            <Text style={[styles.linkText, activeSection === 'deleteUser' && styles.activeLink]}>Delete User</Text>
                        </TouchableOpacity>

                        <TouchableOpacity onPress={() => {toggleSection('addBike'); !(visibleSection === "addBike") && handleSectionToggle('addBike')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                            <Ionicons name="duplicate" size={22} color="gray" {...activeSection === 'addBike' && styles.activeIcon} />
                            <Text style={[styles.linkText, activeSection === 'addBike' && styles.activeLink]}>Add Bike</Text>
                        </TouchableOpacity>

                        <TouchableOpacity onPress={() => {toggleSection('deleteBike'); !(visibleSection === "deleteBike") && handleSectionToggle('deleteBike')}} style={{flexDirection: 'column', alignItems: 'center'}}>
                            <Ionicons name="trash" size={22} color="gray" {...activeSection === 'deleteBike' && styles.activeIcon} />
                            <Text style={[styles.linkText, activeSection === 'deleteBike' && styles.activeLink]}>Delete Bike</Text>
                        </TouchableOpacity>
                    </View>

                    {visibleSection === 'addUser' && (
                    <View style={styles.sectionContainer}>
                        {<CreateUser />}
                    </View>
                    )}

                    {visibleSection === 'deactivateUser' && (
                        <View style={styles.sectionContainer}>
                            {<DeactivateUser />}
                        </View>
                    )}

                    {visibleSection === 'reactivateUser' && (
                    <View style={styles.sectionContainer}>
                        {/* < /> */}
                        {<ReactivateUser/>}
                    </View>
                    )}

                    {visibleSection === 'deleteUser' && (
                    <View style={styles.sectionContainer}>
                        {<DeleteUser />}
                    </View>
                    )}

                    {/* Add Bike Section */}
                    {visibleSection === 'addBike' && (
                    <View style={styles.sectionContainer}>
                        {<AddBike />}
                    </View>
                    )}

                    {/* Delete Bike Section */}
                    {visibleSection === 'deleteBike' && (
                    <View style={styles.sectionContainer}>
                        {<DeleteBike />}
                    </View>
                    )}
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

})
