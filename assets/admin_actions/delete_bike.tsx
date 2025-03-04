import { KeyboardAvoidingView, Text, View, ScrollView, Alert, StatusBar, StyleSheet, Platform, TouchableOpacity, Modal, ActivityIndicator } from "react-native";
import Button1 from "../utilities/button1";
import { useFocusEffect } from "expo-router";
import { useCallback, useState } from "react";
import { collection, query, getDocs, where, deleteDoc } from "firebase/firestore";
import db from "../utilities/firebase_file";

export default function DeleteBike() {

    const [loading, setLoading] = useState<boolean>(false);
    const [bikeList, setBikeList] = useState<any>([]);
    const [selectedBikeToDelete, setSelectedBikeToDelete] = useState<string>('');

    const fetchBikes = async () => {
        setLoading(true);
        try {
          const querySnapshot = await getDocs(collection(db, 'bikes'));
          const bikes = querySnapshot.docs.map((doc) => ({
            id: doc.id,
            ...doc.data(),
          }));
          setBikeList(bikes);
          setLoading(false);
        } catch (error) {
          console.error('Error fetching bikes:', error);
          setLoading(false);
        }
        finally{
            setLoading(false);
        }
    };

    useFocusEffect(
        useCallback(() => {
            fetchBikes();
        }, [])
    );

    const handleDeleteBike = async () => {
        if ( !selectedBikeToDelete ||selectedBikeToDelete.trim() === "") {
            Alert.alert("Error", "Please select a bike first");
            return;
        }

        setLoading(true);
        try {
            const bikeQuery = query(
              collection(db, "bikes"),
              where("plate_number", "==", selectedBikeToDelete)
            );
            
            const querySnapshot = await getDocs(bikeQuery);
          
            if (querySnapshot.empty) {
              Alert.alert("Error", "Bike not found.");
              return;
            }
          
            // Delete only the first matching document
            const bikeDoc = querySnapshot.docs[0];
            await deleteDoc(bikeDoc.ref);
            
            console.log(`Bike with plate number ${selectedBikeToDelete} deleted.`);
            Alert.alert("Success", `Bike with plate number ${selectedBikeToDelete} deleted.`);
          
            // Refresh the bike list and reset the picker
            fetchBikes();
            setSelectedBikeToDelete("");
          } catch (error) {
            console.error("Error deleting bike:", error);
            Alert.alert("Error", "Failed to delete the bike. Please try again.");
          } finally {
            setLoading(false);
            fetchBikes();
          }
    }

    return (
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
                <StatusBar
                    barStyle="light-content"
                    backgroundColor="green"
                />
        
                <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
                <View style={styles.evenInnerContainer2}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 20 }}>
                          {/* <MaterialIcons name="attractions" size={24} color="rgba(200, 0, 0, 0.375)" style={{ marginRight: 8 }} />                       */}
                          <Text style={styles.title4} >Delete an existing bike.</Text>
                        </View>

                        <View style={styles.pickerContainer}>
                            {bikeList.map((option: any, index: number) => (
                                <TouchableOpacity
                                    key={index}
                                    style={styles.radioButtonContainer}
                                    onPress={() => setSelectedBikeToDelete(option.plate_number)}
                                >
                                    <View style={[styles.radioCircleBiggerDel, selectedBikeToDelete === option.plate_number && styles.radioCircleSelectedDel]} />
                                    <Text style={styles.radioTextBigger}>{option.plate_number || "bikeX"}</Text>
                                </TouchableOpacity>
                                ))}
                        </View>

                        <Button1 title={`Delete Bike`} bgColor='rgba(255, 0, 0, 0.775)' onPress={handleDeleteBike} />

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
    evenInnerContainer1: {
        borderRadius: 10,
        padding: 20,
        marginTop: 20,
        backgroundColor: "rgba(0, 78, 0, 0.075)",
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
    title4: {
        fontSize: 24,
        textAlign: 'center',
        fontWeight: 'bold',
        color: 'rgba(200, 0, 0, 0.375)',
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