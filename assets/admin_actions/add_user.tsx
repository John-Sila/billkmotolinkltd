import { KeyboardAvoidingView, Text, View, Image, Modal, TextInput, ScrollView, Alert, StatusBar, StyleSheet, Platform, TouchableOpacity, ActivityIndicator } from "react-native";
import Button1 from "../utilities/button1";
import { useFocusEffect } from "expo-router";
import { useCallback, useEffect, useState } from "react";
import { collection, getDoc, query, getDocs, updateDoc, doc, where, serverTimestamp, setDoc } from "firebase/firestore";
import db, { auth } from "../utilities/firebase_file";
import { createUserWithEmailAndPassword, signInWithEmailAndPassword } from "firebase/auth";
import * as ImagePicker from 'expo-image-picker';

export default function CreateUser() {

    const [loading, setLoading] = useState<boolean>(false);
    const [newEmail, setNewEmail] = useState<string>('');
    const [newPassword, setNewPassword] = useState<string>('');
    const [newUsername, setNewUsername] = useState<string>('');
    const [newPhoneNumber, setNewPhoneNumber] = useState<string>('');
    const [newIDNumber, setNewIDNumber] = useState<string>('');
    const [role, setRole] = useState<string>('Regular User');
    const [adminPassword, setAdminPassword] = useState<string>('');
    const [showPasswordModal, setShowPasswordModal] = useState(false);
    const [message, setMessage] = useState<string>('Please wait');
    const [drivingLicence, setDrivingLicence] = useState<any>(null);
    const [showUserCreatedSuccess, setShowUserCreatedSuccess] = useState<boolean>(false);

    useEffect(() => {
        const requestPermission = async () => {
          const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
          if (status !== 'granted') {
            Alert.alert('Permission required', 'BILLK needs access to your internal media.');
          }

          
        };
        requestPermission();
        // console.log("Date: ", formatDate());
    }, []);

    const pickImage = async () => {
        const result = await ImagePicker.launchImageLibraryAsync({
            mediaTypes: ImagePicker.MediaTypeOptions.Images,
            allowsEditing: true,
        //   aspect: [3, 5],
            quality: 1,
        });

        if (!result.canceled) {
            setDrivingLicence(result.assets[0].uri);
        }
    };


    const AvailableRoles = [
        'Regular User',
        'Admin',
        // 'Road Accident',
    ];

    const getConfirmationModal = () => {
        if (!newEmail || !newPassword || !newUsername || !newPhoneNumber || !newIDNumber || !role ) {
            Alert.alert("Error", "All fields are required.");
            return;
        } else if (!(newUsername.split(" ").length > 1)) {
            Alert.alert("Error", "A username requires 2 names.");
            return;
        } else {
            setShowPasswordModal(true);
        }
    }

    const formatDate = () => {
        const date = new Date();
        const day = date.getDate().toString().padStart(2, '0'); // Ensure two-digit day
        const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const month = monthNames[date.getMonth()]; // Get short month name
        const year = date.getFullYear();
      
        return `${day}-${month}-${year}`;
    };

    const confirmAdminPassword = async () => {
        setShowPasswordModal(false);
        // setLoading(true);
        // setLoadingMessage("Authenticating and creating new user");

        try {
            // Step 1: Save the current admin user's credentials
            const currentUser = auth.currentUser;
            if (!currentUser) {
                Alert.alert("Error", 'Insufficient permissions.');
                return;
            }
            const adminEmail: any = currentUser.email;

            // Step 2: Validate the admin password by re-authenticating
            setLoading(true);
            try {
                await signInWithEmailAndPassword(auth, adminEmail, adminPassword);
            } catch (error) {
                Alert.alert("Error", 'Incorrect admin password. Please try again.');
                return;
            }
            
            // Step 3: Create the new user
            const userCredential = await createUserWithEmailAndPassword(auth, newEmail, newPassword);
            const user = userCredential.user;
            const uid = user.uid;

            // Step 4: image (DL)
            // const resizedImage = await ImageManipulator.manipulateAsync(
            //     drivingLicence, // Source URI
            //     [{ resize: { width: 300 } }], // Resize to width of 300px (adjust as needed)
            //     { compress: 0.7, format: ImageManipulator.SaveFormat.JPEG }
            // );
          
            // const imageRef = ref(storage, `users/${uid}/drivingLicence.jpg`);
            // const response = await fetch(drivingLicence.uri);
            // const blob = await response.blob();
            // await uploadBytes(imageRef, blob);
        
            // 4b. Get download URL of the uploaded image
            // const downloadURL = await getDownloadURL(imageRef);

            
            // images
            // const imageUrl = await uploadDrivingLicenseImageToCloudinary(drivingLicence);
            // if (!imageUrl) throw new Error("Image upload failed");

            // Step 5: Add user details to Firestore
            await setDoc(doc(db, 'users', uid), {
                email: newEmail,
                role: role,
                username: newUsername || null,
                created_at: serverTimestamp(),
                is_active: true,
                daily_target: 2200,
                last_push_date: new Date().toISOString().split('T')[0],
                unpushed_amount: 0,
                amount_pending_approval: 0,
                current_in_app_balance: 0,
                is_deleted: false,
                is_logged_in: false,
                last_clock: formatDate(),
                net_clocked: 0,
                phone_number: newPhoneNumber,
                id_number: newIDNumber,
                
                // drivingLicenceUrl: imageUrl || "none",
            });

            // Step 6: Re-authenticate the admin user
            await signInWithEmailAndPassword(auth, adminEmail, adminPassword);
            setLoading(false);
            setShowUserCreatedSuccess(true);

            setNewEmail('');
            setNewPassword('');
            setNewUsername('');
            setRole('Regular User');
            setNewPassword('');
            setNewPhoneNumber('');
            setNewIDNumber('');
            setDrivingLicence(null);
            setAdminPassword("");

        } catch (error: any) {
            console.error('Error creating user:', error);
            Alert.alert('Error creating user:', error);
            setMessage(`Error: ${error.message}`);
        } finally {
            setShowPasswordModal(false); // Hide the modal
            setLoading(false); //
            // setLoadingMessage("Please wait")
        }
    }

    const uploadDrivingLicenseImageToCloudinary = async (imageUri: string) => {
        const data = new FormData();
        data.append("file", {
            uri: imageUri,
            type: "image/jpeg",
            name: "upload.jpg",
        } as any);
        data.append("upload_preset", "presetsforbillk");
        data.append("cloud_name", "dx0mdwuwx");

        try {
            const response = await fetch("https://api.cloudinary.com/v1_1/dx0mdwuwx/image/upload", {
                method: "POST",
                body: data,
            });
    
            const result = await response.json();
            console.log("Uploaded Image URL:", result.secure_url);
            return result.secure_url; // final image URL
        } catch (error) {
            console.error("Error uploading image:", error);
            return null;
        }
    }
    

    return (
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
                <StatusBar
                    barStyle="light-content"
                    backgroundColor="green"
                />
        
                <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
                <View style={styles.evenInnerContainer1}>
                        <View style={{ flexDirection: 'row', marginBottom: 20, alignItems: 'center', justifyContent: 'center', marginTop: 20 }}>
                            <Text style={styles.title1}>Create New User</Text>
                        </View>

                        <TextInput
                            placeholder="Email"
                            value={newEmail}
                            onChangeText={setNewEmail}
                            style={styles.input}
                            autoCapitalize="none"
                            keyboardType="email-address"
                            />

                        <TextInput
                            placeholder="Password"
                            value={newPassword}
                            onChangeText={setNewPassword}
                            autoCapitalize="none"
                            // secureTextEntry
                            style={styles.input}
                        />

                        <TextInput
                            placeholder="Username"
                            value={newUsername}
                            onChangeText={setNewUsername}
                            style={styles.input}
                        />

                        <TextInput
                            placeholder="Phone number"
                            value={newPhoneNumber}
                            onChangeText={setNewPhoneNumber}
                            style={styles.input}
                            keyboardType="numeric"
                        />

                        <TextInput
                            placeholder="ID Number"
                            value={newIDNumber}
                            onChangeText={setNewIDNumber}
                            style={styles.input}
                            keyboardType="numeric"
                        />

                        <Text style={styles.label}>Select Role:</Text>
                            <View style={styles.rolePickerContainer}>
                                {AvailableRoles.map((option, index) => (
                                <TouchableOpacity
                                    key={index}
                                    style={styles.radioButtonContainer}
                                    onPress={() => setRole(option)}
                                >
                                    <View style={[styles.radioCircleBigger, role === option && styles.radioCircleSelected]} />
                                    <Text style={styles.radioTextBigger}>{option}</Text>
                                </TouchableOpacity>
                                ))}
                        </View>

                        {/* <View style={styles.evenInnerContainer1}>
                            <Text style={styles.label}>User Driving Licence:</Text>
                            <TouchableOpacity style={styles.imagePickerButton} onPress={pickImage}>
                                <Text style={styles.imagePickerButtonText}>Choose Image</Text>
                            </TouchableOpacity>
                            {drivingLicence && (
                                <Image source={{ uri: drivingLicence }} style={styles.profileImage} />
                            )}
                        </View> */}

                        <Button1 title={`Create User ${newUsername}`} bgColor='green' onPress={getConfirmationModal} />

                        {/* Admin Password Modal */}
                        <Modal
                            visible={showPasswordModal}
                            transparent={true}
                            animationType="slide"
                            onRequestClose={() => setShowPasswordModal(false)}
                        >
                            <View style={styles.modalContainer}>
                                <View style={styles.modalContent}>
                                    <Text style={styles.modalTitle}>Enter Admin Password</Text>
                                    <TextInput
                                        placeholder="Admin Password"
                                        value={adminPassword}
                                        onChangeText={setAdminPassword}
                                        secureTextEntry
                                        style={styles.input}
                                    />
                                    <View style={styles.alignContainer}>
                                        <Button1  title={`Initiate`} bgColor='green' onPress={confirmAdminPassword}/>
                                        <Button1  title={`Cancel`} bgColor='rgba(255, 165, 0, 0.775)' onPress={() => setShowPasswordModal(false)}/>
                                    </View>
                                </View>
                            </View>
                        </Modal>

                        {/* user created successfully */}
                        <Modal
                            visible={showUserCreatedSuccess}
                            transparent={true}
                            animationType="slide"
                            onRequestClose={() => setShowUserCreatedSuccess(false)}
                        >
                            <View style={styles.modalContainer}>
                                <View style={styles.modalContent}>
                                    <Text style={styles.modalTitle}>New user was successfully created.</Text>
                                    
                                    <View style={styles.alignContainer1}>
                                        <Button1  title={`Ok`} bgColor='rgba(255, 165, 0, 0.775)' onPress={() => setShowUserCreatedSuccess(false)}/>
                                    </View>
                                </View>
                            </View>
                        </Modal>
                    </View>

                    <Modal transparent={true} visible={loading}>
                        <View style={styles.modalContainer}>
                            <ActivityIndicator size="large" color="green" />
                            <Text style={styles.loadingText}>Creating user...</Text>
                        </View>
                    </Modal>
                </ScrollView>
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
    evenInnerContainer1: {
        borderRadius: 10,
        padding: 20,
        marginTop: 20,
        backgroundColor: "rgba(0, 78, 0, 0.075)",
    },
    message: {
        textAlign: 'center',
        marginTop: 10,
        color: 'green',
        fontWeight: 'bold',
    },
    input: {
        height: 40,
        borderColor: 'rgba(0, 128, 0, 0.175)',
        borderWidth: 1,
        marginBottom: 10,
        paddingLeft: 8,
        borderRadius: 10,
        backgroundColor: '#fff',
    },
    modalContent: {
        width: '80%',
        padding: 20,
        backgroundColor: 'white',
        borderRadius: 10,
    },
    modalTitle: {
        fontSize: 18,
        fontWeight: 'bold',
        marginBottom: 15,
    },
    alignContainer1: {
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'flex-end',
        paddingRight: 10,
    },
    alignContainer: {
        display: 'flex',
        flexDirection: 'row-reverse',
        justifyContent: 'space-around',
    },
    title1: {
        color: "rgba(0, 128, 0, 0.375)",
        fontSize: 24,
        textAlign: 'center',
        fontWeight: 'bold',
        marginBottom: 10,
    },
    imagePickerButton: {
        backgroundColor: 'rgba(255, 165, 0, 0.775)',
        padding: 10,
        marginTop: 20,
        borderRadius: 10,
        marginBottom: 20,
        alignItems: 'center',
    },
    imagePickerButtonText: {
        color: '#fff',
        fontSize: 16,
    },
    profileImage: {
        width: 100,
        height: 150,
        borderRadius: 10,
        marginTop: 10,
        alignSelf: 'center',
    },
    rolePickerContainer: {
        borderWidth: 0,
        borderRadius: 10,
        overflow: "hidden",
        backgroundColor: "rgba(0, 128, 0, 0.075)",
        marginTop: 20,
        marginBottom: 20,
        padding: 20,
    },
    label: {
        fontSize: 18,
        color: "gray",
        fontWeight: 'bold',
        marginTop: 10,
        marginBottom: 0,
    },
    
    radioCircleBigger: {
        height: 30,
        width: 30,
        borderRadius: 10,
        borderWidth: 2,
        borderColor: 'green',
        marginRight: 10,
      },
    radioCircleSelected: {
        backgroundColor: 'green',
    },
    radioTextBigger: {
        fontSize: 16,
        fontWeight: 'bold',
        color: 'gray',
    },
    radioButtonContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 10,
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