# -----------------------------------------------------------------------------
# 🗓️  Appointment Scheduler Script - Bash Version
#
# This script provides a command-line appointment scheduling system using 
# CSV files for persistent storage of user and appointment data.
#
# ➤ Features:
#   - User registration with unique username, password, full name, and profession.
#   - Secure user login with credential verification.
#   - Book appointments with other registered users (not yourself).
#   - View appointments you've booked or that are scheduled with you.
#   - Cancel your own booked appointments.
#   - Approve or reject pending appointments scheduled with you.
#   - View appointment statuses (Pending, Approved, Rejected).
#
# ➤ Data Storage:
#   - users.csv
#     Format: username,password,full_name,profession
#     Stores all user credentials and metadata.
#
#   - appointments.csv
#     Format: ID,BookedBy,Date,Time,WithWhom,ClientName,Reason,Status
#     Stores all appointments made by users.
#
# ➤ Script Workflow:
#   1. Checks if CSV files exist; creates them with headers if not.
#   2. Prompts user to Register or Login.
#   3. After login, shows a menu for appointment operations.
#   4. Each menu action interacts with the appropriate CSV file.
#   5. Uses temporary files to ensure safe read/write operations.
#
# ➤ Usage:
#   - Run the script in a Bash environment: ./apt_sch.sh
#   - Follow on-screen prompts to register, login, and manage appointments.
#
# ➤ Notes:
#   - Only the user who booked an appointment can cancel it.
#   - Only the user with whom the appointment is scheduled can approve/reject.
#   - All status changes are reflected in appointments.csv.
#   - Username must be unique during registration.
# -----------------------------------------------------------------------------






#!/bin/bash

USERS_FILE="users.csv"
APPT_FILE="appointments.csv"
current_user=""
current_name=""
current_profession=""

# Create CSV files if not exist
if [ ! -f "$USERS_FILE" ]; then
  echo "username,password,full_name,profession" > "$USERS_FILE"
fi

if [ ! -f "$APPT_FILE" ]; then
  echo "ID,BookedBy,Date,Time,WithWhom,ClientName,Reason,Status" > "$APPT_FILE"
fi

# Register new user
register() {
  echo "🔐 Register"
  read -p "Username: " username
  # Check username uniqueness (case-sensitive)
  if grep -q "^$username," "$USERS_FILE"; then
    echo "❌ Username already exists."
    return
  fi
  read -p "Password: " password
  echo
  read -p "Confirm Password: " confirm
  echo
  if [ "$password" != "$confirm" ]; then
    echo "❌ Passwords do not match."
    return
  fi
  read -p "Full Name: " full_name
  read -p "Profession (e.g. Teacher, Client, Manager): " profession
  echo "$username,$password,$full_name,$profession" >> "$USERS_FILE"
  echo "✅ Registered successfully."
}

# Login user
login() {
  echo "🔓 Login"
  read -p "Username: " username
  read -p "Password: " password
  echo
  line=$(grep "^$username,$password," "$USERS_FILE")
  if [ -n "$line" ]; then
    current_user="$username"
    current_name=$(echo "$line" | cut -d',' -f3)
    current_profession=$(echo "$line" | cut -d',' -f4)
    echo "✅ Login successful as $current_name ($current_profession)"
    return 0
  else
    echo "❌ Invalid credentials."
    return 1
  fi
}

# Book new appointment
book_appointment() {
  echo "📅 Book New Appointment"
  read -p "Enter Date (YYYY-MM-DD): " date
  read -p "Enter Time (HH:MM): " time
  echo "Available users to book with:"
  cut -d',' -f1,3,4 "$USERS_FILE" | tail -n +2 | column -t -s, | grep -v "^$current_user"
  read -p "Enter username of person you want to book with: " with_whom
  if ! grep -q "^$with_whom," "$USERS_FILE"; then
    echo "❌ No such user found."
    return
  fi
  # Check if the user is trying to book with themselves
  if [ "$with_whom" == "$current_user" ]; then
    echo "❌ You cannot book an appointment with yourself."
    return
  fi
  #auto insert the client name from the user logged in
  client_name="$current_name"
  read -p "Reason for appointment: " reason

  # Check clash (for the user booking)
  if grep -q ",$current_user,$date,$time," "$APPT_FILE"; then
    echo "⚠️ You already have an appointment at that time."
    return
  fi

  last_id=$(tail -n +2 "$APPT_FILE" | cut -d',' -f1 | sort -n | tail -1)
  if [ -z "$last_id" ]; then
    id=1
  else
    id=$((last_id + 1))
  fi

  echo "$id,$current_user,$date,$time,$with_whom,$client_name,$reason,Pending" >> "$APPT_FILE"
  echo "✅ Appointment booked successfully."
}

# View appointments booked by current user
view_booked() {
  echo "📋 Appointments You Booked:"
  matches=$(grep ",$current_user," "$APPT_FILE")
  if [ -z "$matches" ]; then
    echo "No appointments booked by you."
  else
    (head -1 "$APPT_FILE"; echo "$matches") | column -t -s,
  fi
}

# View appointments scheduled with current user
view_your_schedule() {
  echo "📋 Appointments Scheduled With You:"
  matches=$(awk -F',' -v user="$current_user" '$5 == user' "$APPT_FILE")
  if [ -z "$matches" ]; then
    echo "No appointments scheduled with you."
  else
    (head -1 "$APPT_FILE"; echo "$matches") | column -t -s,
  fi
}

# Cancel your own appointment
cancel_appointment() {
  read -p "Enter Appointment ID to cancel: " cancel_id
  if grep -q "^$cancel_id,$current_user," "$APPT_FILE"; then
    grep -v "^$cancel_id,$current_user," "$APPT_FILE" > tmp && mv tmp "$APPT_FILE"
    echo "🗑️ Appointment $cancel_id cancelled."
  else
    echo "❌ You can only cancel appointments you booked."
  fi
}

# Approve or Reject appointments scheduled with you
approve_reject_appointments() {
  echo "📝 Pending Appointments Scheduled With You:"
  pending_apps=$(awk -F',' -v user="$current_user" '$5 == user && $8 == "Pending"' "$APPT_FILE")
  if [ -z "$pending_apps" ]; then
    echo "No pending appointments to approve or reject."
    return
  fi

  (head -1 "$APPT_FILE"; echo "$pending_apps") | column -t -s,

  read -p "Enter Appointment ID to approve/reject (or press ENTER to reject): " app_id
  if [ -z "$app_id" ]; then
    echo "No ID entered. All pending appointments remain unchanged."
    return
  fi

  read -p "Approve (A) or Reject (R)? (Press ENTER to reject): " decision
  decision=$(echo "$decision" | tr '[:upper:]' '[:lower:]')

  # If decision is empty, treat as reject
  if [ -z "$decision" ] || [ "$decision" == "r" ]; then
    status="Rejected"
  elif [ "$decision" == "a" ]; then
    status="Approved"
  else
    echo "❌ Invalid choice."
    return
  fi

  updated=0
  while IFS=',' read -r id booked date time with client reason stat; do
    if [ "$id" = "$app_id" ] && [ "$with" = "$current_user" ] && [ "$stat" = "Pending" ]; then
      echo "$id,$booked,$date,$time,$with,$client,$reason,$status"
      updated=1
    else
      echo "$id,$booked,$date,$time,$with,$client,$reason,$stat"
    fi
  done < <(tail -n +2 "$APPT_FILE") > tmp && (head -1 "$APPT_FILE"; cat tmp) > "$APPT_FILE.tmp" && mv "$APPT_FILE.tmp" "$APPT_FILE"

  if [ $updated -eq 1 ]; then
    echo "✅ Appointment $app_id marked as $status."
  else
    echo "❌ No matching pending appointment found."
  fi
}

# Main menu after login
main_menu() {
  while true; do
    echo
    echo "===== Appointment Scheduler — $current_name ($current_profession) ====="
    echo "1. Book Appointment"
    echo "2. View Appointments You Booked"
    echo "3. View Appointments Scheduled With You"
    echo "4. Cancel Appointment"
    echo "5. Approve/Reject Appointments Scheduled With You"
    echo "6. Logout"
    read -p "Enter choice: " choice
    case $choice in
      1) book_appointment ;;
      2) view_booked ;;
      3) view_your_schedule ;;
      4) cancel_appointment ;;
      5) approve_reject_appointments ;;
      6) echo "👋 Logged out."; break ;;
      *) echo "❌ Invalid choice." ;;
    esac
  done
}

# Login/Register menu
login_menu() {
  while true; do
    echo
    echo "===== Welcome to the Appointment Scheduler ====="
    echo "1. Register"
    echo "2. Login"
    echo "3. Exit"
    read -p "Choose option: " option
    case $option in
      1) register ;;
      2) login && main_menu ;;
      3) echo "👋 Goodbye!"; exit 0 ;;
      *) echo "❌ Invalid choice." ;;
    esac
  done
}

# Start the program
login_menu
