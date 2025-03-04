import { KeyboardAvoidingView, Text, View, ScrollView, Alert, StatusBar, StyleSheet, Platform, TouchableOpacity, ActivityIndicator, Modal } from "react-native";
import Button1 from "../utilities/button1";
import { useFocusEffect } from "expo-router";
import { useCallback, useState } from "react";
import { collection, getDoc, query, getDocs, updateDoc, doc, where } from "firebase/firestore";
import db from "../utilities/firebase_file";

export default function DeleteUser() {

    const [usersList, setUsersList] = useState<any>([]);
    const [loading, setLoading] = useState<boolean>(false);
    const [selectedUserToDelete, setSelectedUserToDelete] = useState<string | null>(null);

    useFocusEffect(
        useCallback(() => {
            fetchEmails();
        }, [])
    );
    const fetchEmails = async () => {
        setLoading(true);
        try {
            const usersQuery = query(collection(db, 'users'));
            const querySnapshot = await getDocs(usersQuery);
            const users = querySnapshot.docs.map((doc: any) => doc.data());
            setUsersList(users);
        } catch (error) {
            Alert.alert('Error', `Failed to fetch user emails. ${error}}`);
        } finally {
            setLoading(false);
        }
    };

    const handleDeleteUser = async () => {
        if (!selectedUserToDelete || selectedUserToDelete.trim() === '') {
          Alert.alert('Error', 'Please select a user.');
          return;
        }
        
        setLoading(true);
      
        try {
          const usersQuery = query(collection(db, 'users'), where('username', '==', selectedUserToDelete));
          const querySnapshot = await getDocs(usersQuery);
      
          if (querySnapshot.empty) {
            Alert.alert('Error', 'User not found.');
            return;
          }
      
          const userDoc = querySnapshot.docs[0];
          const userDocRef = doc(db, 'users', userDoc.id);
      
          // Set is_deleted to true, is_active to false, and add a deleted_on timestamp
          await updateDoc(userDocRef, {
            is_deleted: true,
            is_active: false,
            deleted_on: new Date().toISOString()  // Store the current date as a string
          });
      
          Alert.alert('Success', `${selectedUserToDelete} deleted successfully.`);
        } catch (error: any) {
          Alert.alert('Error', error.message);
        } finally {
          setLoading(false);
          fetchEmails();
        }
    };

    return (
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
                <StatusBar
                    barStyle="light-content"
                    backgroundColor="green"
                />
        
                <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
                    <View style={styles.evenInnerContainer4} >
                            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 20 }}>
                                {/* <MaterialIcons name="delete" size={24} color="rgba(200, 0, 0, 0.375)" style={{ marginRight: 8 }} /> */}
                                <Text style={[styles.title4, { marginTop: 0 }]}>Delete User</Text>
                            </View>

                            <View style={styles.pickerContainer}>
                            {usersList
                                .filter((option: any) => option.role !== "CEO" && !option.is_deleted)
                                .map((option: any, index: number) => (
                                    <TouchableOpacity
                                    key={index}
                                    style={styles.radioButtonContainer}
                                    onPress={() => setSelectedUserToDelete(option.username)}
                                    >
                                        <View style={[styles.radioCircleBiggerDel, selectedUserToDelete === option.username && styles.radioCircleSelectedDel]} />
                                        <Text style={styles.radioTextBigger}>{option.username || "Unknown user"} ({option.role})</Text>
                                    </TouchableOpacity>
                                ))}

                            </View>
                        <Text style={[styles.regText2, { marginTop: 20 }]}>⁕This action is ONLY reversible through Developer privileges.</Text>
                        <Button1 title={`Delete ${selectedUserToDelete? selectedUserToDelete : ""}`} bgColor='rgba(255, 0, 0, 0.775)' onPress={handleDeleteUser} />

                    </View>

                    <Modal transparent={true} visible={loading}>
                        <View style={styles.modalContainer}>
                            <ActivityIndicator size="large" color="rgba(255, 0, 0, 0.775)" />
                            <Text style={styles.loadingText}>Loading...</Text>
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
    evenInnerContainer4: {
        borderRadius: 10,
        // iOS Shadow
        shadowColor: 'rgb(200, 200, 200)',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.2,
        shadowRadius: 5,
        // Android Shadow
        elevation: 0, // Adds shadow on Android
        padding: 20,
        marginTop: 20,
        backgroundColor: "rgba(128, 0, 0, 0.075)",
    },
    pickerContainer: {
        borderColor: "rgba(128, 0, 0, 0.175)",
        borderWidth: .5,
        borderRadius: 10,
        overflow: "hidden",
        backgroundColor: "white",
        marginTop: 20,
        padding: 20,
    },
    title4: {
        fontSize: 24,
        textAlign: 'center',
        fontWeight: 'bold',
        color: 'rgba(200, 0, 0, 0.375)',
    },
    regText2: {
        fontSize: 15,
        textAlign: 'center',
        color: "rgba(255, 0, 0, 0.775)",
        fontFamily: 'monospace',
    },
    radioCircleBiggerDel: {
        height: 30,
        width: 30,
        borderRadius: 10,
        borderWidth: 2,
        borderColor: 'rgba(200, 0, 0, 0.375)',
        marginRight: 10,
      },
    radioCircleSelectedDel: {
        backgroundColor: 'rgba(255, 0, 0, 0.775)',
    },
    radioButtonContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 10,
    },
    radioTextBigger: {
        fontSize: 16,
        fontWeight: 'bold',
        color: 'gray',
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