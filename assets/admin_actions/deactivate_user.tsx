import { KeyboardAvoidingView, Text, View, ScrollView, Alert, StatusBar, StyleSheet, Platform, TouchableOpacity, Modal, ActivityIndicator } from "react-native";
import Button1 from "../utilities/button1";
import { useFocusEffect } from "expo-router";
import { useCallback, useState } from "react";
import { collection, getDoc, query, getDocs, updateDoc, doc, where } from "firebase/firestore";
import db from "../utilities/firebase_file";
import checkAndUpdateUnpushedAmount from "../utilities/check_increment_dates";

export default function DeactivateUser() {

    const [usersList, setUsersList] = useState<any>([]);
    const [loading, setLoading] = useState<boolean>(false);
    const [selectedUserToDeactivate, setSelectedUserToDeactivate] = useState<string | null>(null);

    useFocusEffect(
        useCallback(() => {
            fetchEmails();
            checkAndUpdateUnpushedAmount();
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

    const handleDeactivateUser = async () => {
        if (!selectedUserToDeactivate || selectedUserToDeactivate.trim().length === 0) {
            Alert.alert('Error', 'Please select a user.');
            return;
        }
        setLoading(true);

        try {
            const usersQuery = query(collection(db, 'users'), where('username', '==', selectedUserToDeactivate));
            const querySnapshot = await getDocs(usersQuery);

            if (querySnapshot.empty) {
                Alert.alert('Error', 'User not found.');
                return;
            }

            const userDoc = querySnapshot.docs[0];
            const uid = userDoc.id;

            // Update user's `is_active` field in Firestore
            await updateDoc(doc(db, 'users', uid), {
                is_active: false,
            });

            Alert.alert('Success', 'User deactivated successfully.');
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
                <View style={styles.evenInnerContainer2}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 20 }}>
                        {/* <MaterialIcons name="person-off" size={24} color="rgba(255, 165, 0, 0.775)" style={{ marginRight: 8 }} /> */}
                        <Text style={[styles.title2]}>Deactivate User</Text>
                    </View>
                    {/* <Text style={[styles.title2, { marginTop: 20 }]}>Deactivate User</Text> */}
                    <View style={styles.pickerContainer}>
                    {usersList
                        .filter((option: any) => option.role !== "CEO" && option.is_active && !option.is_deleted)
                        .map((option: any, index: number) => (
                            <TouchableOpacity
                            key={index}
                            style={styles.radioButtonContainer}
                            onPress={() => setSelectedUserToDeactivate(option.username)}
                            >
                            <View style={[styles.radioCircleBiggerD, selectedUserToDeactivate === option.username && styles.radioCircleSelectedD]} />
                            <Text style={styles.radioTextBigger}>{option.username || "Unknown user"} ({option.role})</Text>
                            </TouchableOpacity>
                        ))}

                    </View>
                    <Text style={[styles.regText1, { marginTop: 20 }]}>⁕A deactivated user is dormant. He/she will not be able to login to their account. Billing will also be paused while the restriction persists.</Text>
                    <Button1 title={`Deactivate ${selectedUserToDeactivate ? selectedUserToDeactivate : ""}`} bgColor='rgba(255, 165, 0, 0.775)' onPress={handleDeactivateUser} />
                </View>

                <Modal transparent={true} visible={loading}>
                    <View style={styles.modalContainer}>
                        <ActivityIndicator size="large" color="rgba(255, 165, 0, 0.775)" />
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
    regText1: {
        fontSize: 15,
        textAlign: 'center',
        color: "rgba(255, 165, 0, 0.775)",
        fontFamily: 'monospace',
    },
    pickerContainer: {
        borderWidth: .5,
        borderColor: "rgba(128, 0, 0, 0.175)",
        borderRadius: 10,
        overflow: "hidden",
        backgroundColor: "white",
        marginTop: 20,
        padding: 20,
    },
    radioTextBigger: {
        fontSize: 16,
        fontWeight: 'bold',
        color: 'gray',
    },
    radioCircleBiggerD: {
        height: 30,
        width: 30,
        borderRadius: 10,
        borderWidth: 2,
        borderColor: 'rgba(255, 165, 0, 0.775)',
        marginRight: 10,
      },
    radioCircleSelectedD: {
        backgroundColor: 'rgba(255, 165, 0, 0.775)',
    },
    radioButtonContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 10,
    },
    evenInnerContainer2: {
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
        backgroundColor: 'rgba(255, 165, 0, 0.075)',
    },
    title2: {
        fontSize: 24,
        textAlign: 'center',
        fontWeight: 'bold',
        color: 'rgba(255, 165, 0, 0.775)',
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