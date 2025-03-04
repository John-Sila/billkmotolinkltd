import { Alert, StatusBar, KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, TouchableOpacity, View, Modal, ActivityIndicator } from "react-native";
import Button1 from "../utilities/button1";
import { useFocusEffect } from "expo-router";
import { useCallback, useState } from "react";
import { query, collection, getDocs, updateDoc, doc, where } from "firebase/firestore";
import db from "../utilities/firebase_file";
import checkAndUpdateUnpushedAmount from "../utilities/check_increment_dates";

export default function ReactivateUser() {
    const [usersList, setUsersList] = useState<any>([]);
    const [loading, setLoading] = useState<boolean>(false);

    
    const [selectedUserToReactivate, setSelectedUserToReactivate] = useState<string | null>(null);

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

    const handleReactivateUser = async () => {
        if (!selectedUserToReactivate || selectedUserToReactivate.trim().length === 0) {
        Alert.alert('Error', 'Please select a user.');
        return;
        }
        setLoading(true);

        try {
            const usersQuery = query(collection(db, 'users'), where('username', '==', selectedUserToReactivate));
            const querySnapshot = await getDocs(usersQuery);

            if (querySnapshot.empty) {
                Alert.alert('Error', 'User not found.');
                return;
            }

            const userDoc = querySnapshot.docs[0];
            const uid = userDoc.id;

            // Update user's `is_active` field in Firestore
            await updateDoc(doc(db, 'users', uid), {
                is_active: true,
            });

            Alert.alert('Success', 'User reactivated successfully.');
        } catch (error: any) {
            Alert.alert('Error', error.message);
        }
        finally {
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
            <View style={styles.evenInnerContainer3} >
                <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 20 }}>
                    <Text style={[styles.title3, { marginTop: 0 }]}>Reactivate Inactive User</Text>
                </View>
                <View style={styles.pickerContainer}>
                {usersList
                    .filter((option: any) => !option.is_active && option.role !== "CEO" && !option.is_deleted)
                    .map((option: any, index: number) => (
                        <TouchableOpacity
                        key={index}
                        style={styles.radioButtonContainer}
                        onPress={() => setSelectedUserToReactivate(option.username)}
                        >
                        <View style={[styles.radioCircleBiggerR, selectedUserToReactivate === option.username && styles.radioCircleSelectedR]} />
                        <Text style={styles.radioTextBigger}>{option.username || "Unknown user"}</Text>
                        </TouchableOpacity>
                    ))}

                </View>
                <Button1 title={`Reactivate ${selectedUserToReactivate? selectedUserToReactivate : ""}`} bgColor='rgb(0, 0, 255)' onPress={handleReactivateUser} />
            </View>


            <Modal transparent={true} visible={loading}>
                <View style={styles.modalContainer}>
                    <ActivityIndicator size="large" color="rgb(0, 0, 255)" />
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
    evenInnerContainer3: {
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
        backgroundColor: "rgba(0, 0, 128, 0.075)",
    },
    title3: {
        fontSize: 24,
        textAlign: 'center',
        fontWeight: 'bold',
        color: 'rgba(0, 0, 128, 0.375)',
    },
    radioCircleBiggerR: {
        height: 30,
        width: 30,
        borderRadius: 10,
        borderWidth: 2,
        borderColor: 'rgba(0, 0, 128, 0.375)',
        marginRight: 10,
      },
    radioCircleSelectedR: {
        backgroundColor: 'rgb(0, 0, 255)',
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
