*Motorists Management App*
This is a React Native app designed to manage motorist operations. Admins can view clock-outs, expenses, earnings, and interact with motorists through calls, WhatsApp, and SMS. It includes authentication, password management, filters, and detailed record tracking.

📱 Features
✅ User Authentication (with Firebase Auth)
✅ Password Change (with show/hide toggle)
✅ Display motorist clock-outs (gross, net, expenses)
✅ Filter clock-outs by:
    User
    Date (Today, Yesterday)
    Month
    Year
✅ Toggle filter activation with a switch
✅ Collapsible clock-out views per user
✅ Vibration feedback on toggles and actions
✅ Sound effects on alerts (optional)
✅ Make phone calls, WhatsApp chats, and SMS messages directly from the app
✅ Icons for actions (using Ionicons)
✅ Scrollable sections with height limits
✅ Dynamic data fetching from Firebase Firestore


*⚙️ Tech Stack*
    Tech Description
    React Native Frontend framework
    Expo Development environment
    Firebase Authentication & Firestore
    Ionicons Iconography
    React Navigation Tab and stack navigation

*🛠 Setup*
    Clone the repo:

bash
Copy
Edit
git clone https://github.com/johnsila/billkmotolinkltd.git
cd bml
Install dependencies:

    bash
    Copy
    Edit
    npm install
    Start the app:

    bash
    Copy
    Edit
    npx expo start
    Setup Firebase:

Create a Firebase project.
Add your web config to the project.
Set up Firestore with the following structure:
yaml
Copy
Edit
    --users/
    --{uid}/
        --email: string
        --username: string
        --role: string
        --clock_outs/
        --{date}/
            --gross: number
            --net: number
            --expenses:
            --battery_swap: number
            --lunch: number
            --police: number
            --other:
                --name: string
                --amount: number


*📌 Key Files*
File Purpose
App.tsx	- Main entry point
    components/ClockOuts	Renders user clock-outs
    components/Filters	Handles filter toggles
    firebase.js	Firebase config
    navigation/	Tab and stack navigation
🔔 Improvements to come
    Notifications for new clock-outs.
    Deeper filter options (by week, custom ranges).
    Dark mode support.
    Offline support with cached data.
    Better animations for collapsible views.
💡 Usage
    Admins can track earnings.
    View and manage motorist expenses.
    Call or message drivers directly from their profiles.
    Secure password management with visibility toggles.


*🧑‍💻 Author*
JOHN SILA
[jsila3000@gmail.com]
[https://github.com/John-Sila]


📄 License
BILLK MOTOLINK LTD is a closed source software.