// screens/HomeScreen.js
import React, { useCallback, useEffect, useState } from 'react';
import { View, Text, TextInput, StyleSheet, ActivityIndicator, Modal, Alert, TouchableOpacity, ScrollView, KeyboardAvoidingView, Platform} from 'react-native';
// import RNPickerSelect from 'react-native-picker-select';
import { collection, getDocs, addDoc, serverTimestamp, getDoc, doc } from 'firebase/firestore';
import { useFocusEffect } from '@react-navigation/native';
import * as Location from "expo-location";
import { Ionicons } from '@expo/vector-icons';
import Button1 from '@/assets/utilities/button1';
import db, { auth } from '@/assets/utilities/firebase_file';
import { signOut } from 'firebase/auth';
import CheckIfThisUserIsStillLoggedIn from '@/assets/utilities/check_login_status';
import checkAndUpdateUnpushedAmount from '@/assets/utilities/check_increment_dates';

export default function ReportingScreen({ navigation: any }: any) {
  const [selectedReportType, setSelectedReportType] = useState('Mechanical Breakdown');
  const [selectedOption, setSelectedOption] = useState('');
  const [bikeList, setBikeList] = useState<any>([]);
  const [selectedBike, setSelectedBike] = useState("");
  const [loading, setLoading] = useState(true);
  const [userInput, setUserInput] = useState<string>("");
  const [currentAction, setcurrentAction] = useState("Getting BILLK bikes");

  useEffect( () => {
    setSelectedOption('');
  }, [selectedReportType])

  const fetchBikes = async () => {
    setLoading(true);
    try {
      const querySnapshot = await getDocs(collection(db, 'bikes'));
      const bikes = querySnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));
      setBikeList(bikes);
    //   console.log(bikes)
    } catch (error) {
      console.error('Error fetching bikes:', error);
    }
    finally {
      setLoading(false);
    }
  };

  useFocusEffect(
      useCallback(() => {
        fetchBikes();
        CheckIfThisUserIsStillLoggedIn();
        checkAndUpdateUnpushedAmount();
      }, [])
  );


  const ReportTypes = [
    'Mechanical Breakdown',
    'Police Arrest',
    'Road Accident',
  ];


  const optionsForMechanicalBreakdown = [
    'Ran out of charge',
    'Bike randomly shut down',
    'Bike is on but won\'t move',
    'A part fell off/apart',
  ];
  const optionsForPoliceArrest = [
    'Overspeeding',
    'Got involved in an accident',
    'Road signs and traffic rule violation',
    'Road misbehavior',
    'You hit a police officer',
    'Lacking/Faulty bike part(s)',
    'Insufficient/unavailable/invalid documents',
    'Illegal/On-the-run passenger/cargo',
  ];
  const optionsForRoadAccident = [
    'You hit another car',
    'You hit a bike rider',
    'Someone hit you',
    'You hit a pedestrian',
  ];

  const addReport = async () => {
      if (selectedReportType === "" || selectedOption === "" || selectedBike.trim() === "") {
        Alert.alert("Error!", "Fill all form requirements first.");
        return;
      }

      setcurrentAction("Submitting report");
      setLoading(true);

      try {
          const user = auth.currentUser; // Get the current logged-in user
          const rider = user ? user.displayName || user.email : 'Unknown Rider'; // Use displayName or email as the rider's name
          const username = async () => {
            if (!user) {
              console.log("No authenticated user found.");
              return null;
            }
        
            const userDocRef = doc(db, "users", user.uid); // Reference to Firestore document
            const userDocSnap = await getDoc(userDocRef); // Fetch user document
        
            if (userDocSnap.exists()) {
              const userData = userDocSnap.data();
              console.log("Username:", userData.username);
              return userData.username;
            } else {
              console.log("User document does not exist.");
              return null;
            }
          }

          // location
          const location = await Location.getCurrentPositionAsync({});
          console.log("Current Location:", location.coords);
          
          const reportData = {
            report_type: selectedReportType,
            report_description: selectedOption,
            rider: await username(),
            bike: selectedBike,
            created_at: serverTimestamp(), // Add a timestamp for when the report was created
            location: {
              latitude: location.coords.latitude,
              longitude: location.coords.longitude,
              accuracy: location.coords.accuracy,
            },
            report_time: new Date().toISOString(),
          };
          // Add the report to the "reports" collection in Firestore
          await addDoc(collection(db, 'reports'), reportData);
      
          Alert.alert('Success', 'Report submitted successfully');
      } catch (error) {
          console.error('Error submitting report:', error);
          Alert.alert('Failed to submit report. Please try again.');
      } finally {
          setSelectedReportType('');
          setSelectedBike('');
          setSelectedOption('');
          setLoading(false);
          setcurrentAction('Getting BILLK bikes');
      }
  };

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
      <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
        <View style={styles.innerContainer}>
          <View style={styles.evenInnerContainer}>
            <Text style={styles.title} >For performance evaluation, make sure to report all unexpected incidents.</Text>
          </View>

          <View style={styles.evenInnerContainer}>
            <Text style={styles.normalText}>Choose the nature of your report below</Text>
            <View style={styles.pickerContainer}>
            </View>

            <View style={styles.evenInnerContainer1}>
                <Text style={styles.largerTitle}>A Report for a:</Text>
                <View style={styles.container}>
                  {ReportTypes.map((option, index) => (
                    <TouchableOpacity
                      key={index}
                      style={styles.radioButtonContainer}
                      onPress={() => setSelectedReportType(option)}
                    >
                      <View style={[styles.radioCircleBigger, selectedReportType === option && styles.radioCircleSelected]} />
                      <Text style={styles.radioTextBigger}>{option}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
            </View>

            
            {selectedReportType === "Mechanical Breakdown" && (
              <View style={styles.evenInnerContainer}>
                <Text style={styles.tinierTitle}>Select the nature of the breakdown.</Text>
                <View style={styles.container}>
                  {optionsForMechanicalBreakdown.map((option, index) => (
                    <TouchableOpacity
                      key={index}
                      style={styles.radioButtonContainer}
                      onPress={() => setSelectedOption(option)}
                    >
                      <View style={[styles.radioCircle, selectedOption === option && styles.radioCircleSelected]} />
                      <Text style={styles.radioText}>{option}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            )}

            {selectedReportType === "Road Accident" && (
              <View style={styles.evenInnerContainer}>
                <Text style={styles.tinierTitle}>What best describes this accident?</Text>
                <View style={styles.container}>
                  {optionsForRoadAccident.map((option, index) => (
                    <TouchableOpacity
                      key={index}
                      style={styles.radioButtonContainer}
                      onPress={() => setSelectedOption(option)}
                    >
                      <View style={[styles.radioCircle, selectedOption === option && styles.radioCircleSelected]} />
                      <Text style={styles.radioText}>{option}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            )}

            {selectedReportType === "Police Arrest" && (
              <View style={styles.evenInnerContainer}>
                <Text style={styles.tinierTitle}>What best describes the cause of this arrest?</Text>
                <View style={styles.container}>
                  {optionsForPoliceArrest.map((option, index) => (
                    <TouchableOpacity
                      key={index}
                      style={styles.radioButtonContainer}
                      onPress={() => setSelectedOption(option)}
                    >
                      <View style={[styles.radioCircle, selectedOption === option && styles.radioCircleSelected]} />
                      <Text style={styles.radioText}>{option}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            )}

            <View style={styles.evenInnerContainer1}>
                <Text style={styles.largerTitle}>Choose Involved Bike:</Text>
                <View style={styles.container}>
                  {bikeList.map((option: any, index: number) => (
                    <TouchableOpacity
                      key={index}
                      style={styles.radioButtonContainer}
                      onPress={() => setSelectedBike(option.plate_number)}
                    >
                      <View style={[styles.radioCircleBigger, selectedBike === option.plate_number && styles.radioCircleSelected]} />
                      <Text style={styles.radioTextBigger}>{option.plate_number || "bikeX"}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
            </View>
            


            <Button1 title={`Report ${selectedReportType}`} bgColor='green' onPress={addReport} />

            {/* Loading Modal */}
            <Modal transparent={true} visible={loading}>
                <View style={styles.modalContainer}>
                  <ActivityIndicator size="large" color="orange" />
                  <Text style={styles.loadingText}>{currentAction}...</Text>
                </View>
            </Modal>


          </View>
        </View>
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
  innerContainer: {
      flex: 1,
      justifyContent: 'center',
      backgroundColor: "rgba(0, 78, 0, 0.075)",
  },
  evenInnerContainer: {
      borderRadius: 10,
      padding: 20,
  },
  evenInnerContainer1: {
      borderRadius: 20,
      padding: 20,
      backgroundColor: "rgba(0, 128, 0, 0.075)",
      marginTop: 20,
  },
  title: {
    fontSize: 22,
    textAlign: 'center',
    marginBottom: 0,
    color: "green",
    fontWeight: 'bold',
  },
  tinierTitle: {
    fontSize: 18,
    textAlign: 'center',
    marginTop: 10,
    color: "orange",
    fontWeight: 'bold',
  },
  largerTitle: {
    fontSize: 22,
    textAlign: 'center',
    marginTop: 10,
    color: "orange",
    fontWeight: 'bold',
  },


  normalText: {
    fontSize: 17,
  },
  pickerContainer: {
    borderWidth: .5,
    borderColor: "green",
    borderRadius: 10,
    overflow: "hidden", // Ensures the picker respects the border radius
    backgroundColor: "white",
    marginTop: 20,
  },
  picker: {
    height: 50,
    width: '100%',
  },
  container: {
    marginTop: 10,
  },
  radioButtonContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 10,
  },
  radioCircle: {
    height: 20,
    width: 20,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: 'green',
    marginRight: 10,
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
  icons: {

  },
  radioText: {
    fontSize: 16,
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
    backgroundColor: 'rgba(0, 0, 0, .8)',
  },
  loadingText: {
    marginTop: 10,
    fontSize: 16,
    color: '#fff',
  },
  
});
