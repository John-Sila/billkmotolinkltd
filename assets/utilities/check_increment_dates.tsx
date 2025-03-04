import { updateDoc, doc, collection, getDocs } from "firebase/firestore";
import db from "./firebase_file";

const checkAndUpdateUnpushedAmount = async () => {
    // if (role === "Regular User") {
    //   const userDocRef = doc(db, 'users', uid);
    //   const userDoc = await getDoc(userDocRef);
  
    //   if (userDoc.exists()) {
    //     const userData = userDoc.data();
    //     const today = new Date().toISOString().split('T')[0];
        
    //     if (userData.last_push_date !== today) {
    //       const lastPushDate: Date = new Date(userData.last_push_date);
    //       const currentDate: Date = new Date(today);
          
    //       // Calculate the difference in days
    //       const timeDifference = currentDate.getTime() - lastPushDate.getTime();
    //       const daysDifference = Math.floor(timeDifference / (1000 * 60 * 60 * 24));
    //       // console.log("LastPushDateInDB:" + daysDifference);
  
    //       if (daysDifference > 0) {
    //         const incrementAmount = daysDifference * parseInt(userData.daily_target);
    //         await updateDoc(userDocRef, {
    //           unpushed_amount: userData.unpushed_amount + incrementAmount,
    //           last_push_date: today
    //         });
    //         console.log(`unpushed_amount incremented by ${incrementAmount} for ${daysDifference} days.`);
    //       }
    //     }
    //   }
      
    // } else if (role === "Admin" || role === "CEO") {
      const usersCollectionRef = collection(db, 'users');
      const today = new Date().toISOString().split('T')[0]; // Current date in 'YYYY-MM-DD' format
      
      try {
        const querySnapshot = await getDocs(usersCollectionRef);
    
        querySnapshot.forEach(async (userDoc) => {
          const userData = userDoc.data();


          const day = new Date().getDay();
          console.log("day: ",day);

          if (!userData.is_deleted && userData.is_active && userData.role !== "CEO") { // Skip deleted, inactive & CEO users
            const userDocRef = doc(db, 'users', userDoc.id);
    
            if (userData.last_push_date !== today) {
              const lastPushDate: Date = new Date(userData.last_push_date);
              const currentDate: Date = new Date(today);
    
              const timeDifference = currentDate.getTime() - lastPushDate.getTime();
              const daysDifference = Math.floor(timeDifference / (1000 * 60 * 60 * 24));

              
    
              if (daysDifference > 0) {
                const incrementAmount = daysDifference * parseInt(userData.daily_target);
                await updateDoc(userDocRef, {
                  unpushed_amount: userData.unpushed_amount + incrementAmount,
                  last_push_date: today,
                });
                console.log(`unpushed_amount incremented by ${incrementAmount} for ${daysDifference} days for user ${userData.email}.`);
              }
            }
          } else if (!userData.is_deleted && !userData.is_active && userData.role !== "CEO") {
            // this is a deactivated user
            const userDocRef = doc(db, 'users', userDoc.id);
    
            if (userData.last_push_date !== today) {
              const lastPushDate: Date = new Date(userData.last_push_date);
              const currentDate: Date = new Date(today);
    
              const timeDifference = currentDate.getTime() - lastPushDate.getTime();
              const daysDifference = Math.floor(timeDifference / (1000 * 60 * 60 * 24));
    
              if (daysDifference > 0) {
                const incrementAmount = daysDifference * parseInt(userData.daily_target);
                await updateDoc(userDocRef, {
                  // unpushed_amount: userData.unpushed_amount + incrementAmount,
                  last_push_date: today,
                });
                console.log(`${userData.email} skipped [inactive].`);
              }
            }

          }
      });

        console.log("Checked update amounts");
      } catch (error) {
        console.error("Error updating unpushed_amount for all users:", error);
      }
    // }
  };

  export default checkAndUpdateUnpushedAmount;