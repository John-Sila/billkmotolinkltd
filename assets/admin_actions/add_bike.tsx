import { KeyboardAvoidingView, Text, View, ScrollView, Alert, StatusBar, StyleSheet, Platform, TouchableOpacity, TextInput, Modal, ActivityIndicator } from "react-native";
import Button1 from "../utilities/button1";
import { useFocusEffect } from "expo-router";
import { useCallback, useState } from "react";
import { collection, getDoc, query, getDocs, updateDoc, doc, where, serverTimestamp, addDoc } from "firebase/firestore";
import db from "../utilities/firebase_file";
import checkAndUpdateUnpushedAmount from "../utilities/check_increment_dates";

export default function AddBike() {

    const [loading, setLoading] = useState<boolean>(false);
    const [newPlateNumber, setNewPlateNumber] = useState<string>('');

    
    useFocusEffect(
        useCallback(() => {
            checkAndUpdateUnpushedAmount();
        }, [])
      );

    const handleAddBike = async () => {
        setLoading(true);
        if (!newPlateNumber) {
          Alert.alert("Error", 'Please enter a valid plate number');
          return;
        }

        const cleanedPlateNumber = newPlateNumber.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();

        if (cleanedPlateNumber === '') {
            Alert.alert("Error", 'Plate number is not valid after cleaning. Please enter letters or digits only.');
            return;
        }

        try {
          const bikeData = {
            plate_number: cleanedPlateNumber,
            created_at: serverTimestamp(),
          };
      
          // Add the new bike to the "bikes" collection with a unique document ID
          await addDoc(collection(db, 'bikes'), bikeData);
      
          Alert.alert('Success', 'Bike added successfully!');
      
          // Reset the input field
          setNewPlateNumber('');
        } catch (error) {
          console.error('Error adding bike:', error);
          Alert.alert('Error', 'Failed to add bike. Please try again.');
        }
        finally {
            setLoading(false);
        }
    };

    return (
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
                <StatusBar
                    barStyle="light-content"
                    backgroundColor="green"
                />
        
                <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
                <View style={styles.evenInnerContainer1}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 20 }}>
                          <Text style={styles.title1} >Add a new bike.</Text>
                        </View>

                        <TextInput
                            placeholder="Plate Number (Numbers and Letters only)"
                            value={newPlateNumber}
                            onChangeText={setNewPlateNumber}
                            style={styles.input}
                            autoCapitalize="none"
                        />
                        <Button1 title={`Create new bike ${newPlateNumber? `(${newPlateNumber.replace(" ", "").toUpperCase()})` : ""}`} bgColor='green' onPress={handleAddBike} />

                    </View>

                    <Modal transparent={true} visible={loading}>
                        <View style={styles.modalContainer}>
                            <ActivityIndicator size="large" color="green" />
                            <Text style={styles.loadingText}>Adding bike...</Text>
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
    input: {
        height: 40,
        borderColor: 'rgba(0, 128, 0, 0.175)',
        borderWidth: 1,
        marginBottom: 10,
        paddingLeft: 8,
        borderRadius: 10,
        backgroundColor: '#fff',
    },
    title1: {
        color: "rgba(0, 128, 0, 0.375)",
        fontSize: 24,
        textAlign: 'center',
        fontWeight: 'bold',
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