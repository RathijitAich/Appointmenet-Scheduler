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
RECURRING_FILE="recurring_appointments.csv"
NOTIFICATIONS_FILE="notifications.csv"
current_user=""
current_name=""
current_profession=""

# Create CSV files if not exist
if [ ! -f "$USERS_FILE" ]; then
  echo "username,password,full_name,profession,email,phone,timezone" > "$USERS_FILE"
fi

if [ ! -f "$APPT_FILE" ]; then
  echo "ID,BookedBy,Date,Time,WithWhom,ClientName,Reason,Status,Duration,Priority,Location,Notes,CreatedDate" > "$APPT_FILE"
fi

if [ ! -f "$RECURRING_FILE" ]; then
  echo "ID,BaseAppointmentID,RecurrenceType,RecurrenceInterval,EndDate,NextOccurrence" > "$RECURRING_FILE"
fi

if [ ! -f "$NOTIFICATIONS_FILE" ]; then
  echo "ID,UserName,AppointmentID,Message,Type,Timestamp,Read" > "$NOTIFICATIONS_FILE"
fi

# Utility functions
validate_date() {
  local date=$1
  if [[ ! $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    return 1
  fi
  # Additional date validation can be added here
  return 0
}

validate_time() {
  local time=$1
  if [[ ! $time =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    return 1
  fi
  return 0
}

# Convert time to minutes for comparison
time_to_minutes() {
  local time=$1
  local hours=${time%:*}
  local minutes=${time#*:}
  echo $((hours * 60 + minutes))
}

# Check for appointment conflicts
check_conflicts() {
  local user=$1
  local date=$2
  local start_time=$3
  local duration=$4
  local exclude_id=${5:-""}
  
  local start_minutes=$(time_to_minutes "$start_time")
  local end_minutes=$((start_minutes + duration))
  
  while IFS=',' read -r id booked_by appt_date appt_time with_whom client reason status appt_duration priority location notes created; do
    if [[ "$id" == "ID" ]] || [[ "$id" == "$exclude_id" ]]; then
      continue
    fi
    
    if [[ "$appt_date" == "$date" ]] && ([[ "$booked_by" == "$user" ]] || [[ "$with_whom" == "$user" ]]) && [[ "$status" != "Rejected" ]] && [[ "$status" != "Cancelled" ]]; then
      local existing_start=$(time_to_minutes "$appt_time")
      local existing_end=$((existing_start + appt_duration))
      
      if [[ $start_minutes -lt $existing_end ]] && [[ $end_minutes -gt $existing_start ]]; then
        return 1  # Conflict found
      fi
    fi
  done < "$APPT_FILE"
  
  return 0  # No conflict
}

# Add notification
add_notification() {
  local username=$1
  local appointment_id=$2
  local message=$3
  local type=$4
  
  local last_id=$(tail -n +2 "$NOTIFICATIONS_FILE" | cut -d',' -f1 | sort -n | tail -1)
  if [ -z "$last_id" ]; then
    local id=1
  else
    local id=$((last_id + 1))
  fi
  
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$id,$username,$appointment_id,$message,$type,$timestamp,false" >> "$NOTIFICATIONS_FILE"
}

# Enhanced Register new user
register() {
  echo "🔐 Enhanced User Registration"
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
  read -p "Email: " email
  read -p "Phone: " phone
  read -p "Timezone (e.g. EST, PST, GMT): " timezone
  echo "$username,$password,$full_name,$profession,$email,$phone,$timezone" >> "$USERS_FILE"
  echo "✅ Registered successfully with enhanced profile."
}

# Enhanced login user
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
    
    # Show pending notifications
    local pending=$(grep ",$current_user," "$NOTIFICATIONS_FILE" | grep ",false$" | wc -l)
    if [ $pending -gt 0 ]; then
      echo "🔔 You have $pending unread notification(s)."
    fi
    
    return 0
  else
    echo "❌ Invalid credentials."
    return 1
  fi
}

# Enhanced Book new appointment
book_appointment() {
  echo "📅 Book New Appointment (Enhanced)"
  
  while true; do
    read -p "Enter Date (YYYY-MM-DD): " date
    if validate_date "$date"; then
      break
    else
      echo "❌ Invalid date format. Please use YYYY-MM-DD."
    fi
  done
  
  while true; do
    read -p "Enter Time (HH:MM): " time
    if validate_time "$time"; then
      break
    else
      echo "❌ Invalid time format. Please use HH:MM (24-hour format)."
    fi
  done
  
  while true; do
    read -p "Duration in minutes (default 60): " duration
    if [[ -z "$duration" ]]; then
      duration=60
      break
    elif [[ "$duration" =~ ^[0-9]+$ ]] && [ "$duration" -gt 0 ]; then
      break
    else
      echo "❌ Please enter a valid duration in minutes."
    fi
  done
  
  echo "Available users to book with:"
  cut -d',' -f1,3,4 "$USERS_FILE" | tail -n +2 | column -t -s, | grep -v "^$current_user"
  read -p "Enter username of person you want to book with: " with_whom
  
  if ! grep -q "^$with_whom," "$USERS_FILE"; then
    echo "❌ No such user found."
    return
  fi
  
  if [ "$with_whom" == "$current_user" ]; then
    echo "❌ You cannot book an appointment with yourself."
    return
  fi
  
  # Check for conflicts
  if ! check_conflicts "$current_user" "$date" "$time" "$duration"; then
    echo "⚠️ Conflict detected! You have overlapping appointments."
    echo "Would you like to see alternative time slots? (y/n)"
    read -p "Answer: " show_alternatives
    if [[ "$show_alternatives" =~ ^[Yy]$ ]]; then
      suggest_alternative_times "$date" "$with_whom" "$duration"
    fi
    return
  fi
  
  if ! check_conflicts "$with_whom" "$date" "$time" "$duration"; then
    echo "⚠️ Conflict detected! $with_whom has overlapping appointments."
    echo "Would you like to see alternative time slots? (y/n)"
    read -p "Answer: " show_alternatives
    if [[ "$show_alternatives" =~ ^[Yy]$ ]]; then
      suggest_alternative_times "$date" "$with_whom" "$duration"
    fi
    return
  fi
  
  client_name="$current_name"
  read -p "Reason for appointment: " reason
  
  echo "Priority Level:"
  echo "1. High"
  echo "2. Medium" 
  echo "3. Low"
  read -p "Select priority (1-3, default 2): " priority_choice
  case $priority_choice in
    1) priority="High" ;;
    3) priority="Low" ;;
    *) priority="Medium" ;;
  esac
  
  read -p "Location (optional): " location
  read -p "Additional notes (optional): " notes
  
  echo "Is this a recurring appointment? (y/n)"
  read -p "Answer: " is_recurring
  
  last_id=$(tail -n +2 "$APPT_FILE" | cut -d',' -f1 | sort -n | tail -1)
  if [ -z "$last_id" ]; then
    id=1
  else
    id=$((last_id + 1))
  fi
  
  created_date=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$id,$current_user,$date,$time,$with_whom,$client_name,$reason,Pending,$duration,$priority,$location,$notes,$created_date" >> "$APPT_FILE"
  
  # Add notification for the person being booked with
  add_notification "$with_whom" "$id" "New appointment request from $current_name on $date at $time" "APPOINTMENT_REQUEST"
  
  if [[ "$is_recurring" =~ ^[Yy]$ ]]; then
    setup_recurring_appointment "$id"
  fi
  
  echo "✅ Appointment booked successfully with ID: $id"
}

# Suggest alternative time slots
suggest_alternative_times() {
  local date=$1
  local with_whom=$2
  local duration=$3
  
  echo "🕐 Suggesting alternative time slots for $date:"
  local suggested=0
  
  for hour in {8..17}; do
    for minute in "00" "30"; do
      local test_time=$(printf "%02d:%s" $hour $minute)
      if check_conflicts "$current_user" "$date" "$test_time" "$duration" && check_conflicts "$with_whom" "$date" "$test_time" "$duration"; then
        echo "   ✅ $test_time (${duration} minutes)"
        suggested=$((suggested + 1))
        if [ $suggested -ge 5 ]; then
          break 2
        fi
      fi
    done
  done
  
  if [ $suggested -eq 0 ]; then
    echo "   ❌ No available slots found for $date"
  fi
}

# Setup recurring appointment
setup_recurring_appointment() {
  local base_id=$1
  
  echo "Setting up recurring appointment..."
  echo "1. Weekly"
  echo "2. Bi-weekly"
  echo "3. Monthly"
  read -p "Select recurrence type (1-3): " recurrence_type
  
  case $recurrence_type in
    1) recurrence="Weekly"; interval=7 ;;
    2) recurrence="Bi-weekly"; interval=14 ;;
    3) recurrence="Monthly"; interval=30 ;;
    *) echo "❌ Invalid choice"; return ;;
  esac
  
  read -p "How many occurrences? (max 12): " occurrences
  if [[ ! "$occurrences" =~ ^[0-9]+$ ]] || [ "$occurrences" -gt 12 ] || [ "$occurrences" -lt 1 ]; then
    echo "❌ Invalid number of occurrences"
    return
  fi
  
  # Get the base appointment details
  local base_line=$(grep "^$base_id," "$APPT_FILE")
  local base_date=$(echo "$base_line" | cut -d',' -f3)
  
  # Calculate end date
  local end_date=$(date -d "$base_date + $((interval * occurrences)) days" '+%Y-%m-%d' 2>/dev/null || echo "$base_date")
  local next_occurrence=$(date -d "$base_date + $interval days" '+%Y-%m-%d' 2>/dev/null || echo "$base_date")
  
  # Add to recurring appointments file
  local recurring_id=$(tail -n +2 "$RECURRING_FILE" | cut -d',' -f1 | sort -n | tail -1)
  if [ -z "$recurring_id" ]; then
    recurring_id=1
  else
    recurring_id=$((recurring_id + 1))
  fi
  
  echo "$recurring_id,$base_id,$recurrence,$interval,$end_date,$next_occurrence" >> "$RECURRING_FILE"
  echo "✅ Recurring appointment setup complete"
}

# Enhanced View appointments booked by current user
view_booked() {
  echo "📋 Enhanced View: Appointments You Booked"
  echo "Filter by:"
  echo "1. All appointments"
  echo "2. By status"
  echo "3. By date range"
  echo "4. By priority"
  read -p "Choose filter (1-4): " filter_choice
  
  local filter_condition=""
  case $filter_choice in
    2)
      echo "Status options: Pending, Approved, Rejected, Cancelled"
      read -p "Enter status: " status_filter
      filter_condition="status:$status_filter"
      ;;
    3)
      read -p "Start date (YYYY-MM-DD): " start_date
      read -p "End date (YYYY-MM-DD): " end_date
      filter_condition="daterange:$start_date:$end_date"
      ;;
    4)
      echo "Priority options: High, Medium, Low"
      read -p "Enter priority: " priority_filter
      filter_condition="priority:$priority_filter"
      ;;
  esac
  
  local matches=""
  while IFS=',' read -r id booked_by date time with_whom client reason status duration priority location notes created; do
    if [ "$booked_by" == "$current_user" ]; then
      local include=true
      
      case $filter_condition in
        status:*)
          local filter_status=${filter_condition#status:}
          if [ "$status" != "$filter_status" ]; then
            include=false
          fi
          ;;
        daterange:*)
          local start_date=${filter_condition#daterange:}
          start_date=${start_date%:*}
          local end_date=${filter_condition#*:*:}
          if [[ "$date" < "$start_date" ]] || [[ "$date" > "$end_date" ]]; then
            include=false
          fi
          ;;
        priority:*)
          local filter_priority=${filter_condition#priority:}
          if [ "$priority" != "$filter_priority" ]; then
            include=false
          fi
          ;;
      esac
      
      if [ "$include" == "true" ]; then
        if [ -z "$matches" ]; then
          matches="$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created"
        else
          matches="$matches"$'\n'"$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created"
        fi
      fi
    fi
  done < <(tail -n +2 "$APPT_FILE")
  
  if [ -z "$matches" ]; then
    echo "No appointments found matching your criteria."
  else
    (head -1 "$APPT_FILE"; echo "$matches") | column -t -s,
  fi
}

# Enhanced View appointments scheduled with current user
view_your_schedule() {
  echo "📋 Enhanced View: Appointments Scheduled With You"
  echo "Filter by:"
  echo "1. All appointments"
  echo "2. Pending appointments only"
  echo "3. Today's appointments"
  echo "4. This week's appointments"
  echo "5. Upcoming appointments"
  read -p "Choose filter (1-5): " filter_choice
  
  local today=$(date '+%Y-%m-%d')
  local week_end=$(date -d "+7 days" '+%Y-%m-%d' 2>/dev/null || date '+%Y-%m-%d')
  
  local matches=""
  while IFS=',' read -r id booked_by date time with_whom client reason status duration priority location notes created; do
    if [ "$with_whom" == "$current_user" ]; then
      local include=true
      
      case $filter_choice in
        2)
          if [ "$status" != "Pending" ]; then
            include=false
          fi
          ;;
        3)
          if [ "$date" != "$today" ]; then
            include=false
          fi
          ;;
        4)
          if [[ "$date" < "$today" ]] || [[ "$date" > "$week_end" ]]; then
            include=false
          fi
          ;;
        5)
          if [[ "$date" < "$today" ]]; then
            include=false
          fi
          ;;
      esac
      
      if [ "$include" == "true" ]; then
        if [ -z "$matches" ]; then
          matches="$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created"
        else
          matches="$matches"$'\n'"$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created"
        fi
      fi
    fi
  done < <(tail -n +2 "$APPT_FILE")
  
  if [ -z "$matches" ]; then
    echo "No appointments found matching your criteria."
  else
    echo "$matches" | sort -t',' -k3,3 -k4,4 | (echo "$(head -1 "$APPT_FILE")"; cat) | column -t -s,
  fi
}

# Search and Filter Appointments
search_appointments() {
  echo "🔍 Advanced Appointment Search"
  echo "Search by:"
  echo "1. Keyword in reason/notes"
  echo "2. Date range"
  echo "3. User name"
  echo "4. Status"
  echo "5. Priority"
  echo "6. Location"
  read -p "Choose search type (1-6): " search_type
  
  case $search_type in
    1)
      read -p "Enter keyword: " keyword
      echo "🔍 Searching for appointments containing '$keyword':"
      grep -i "$keyword" "$APPT_FILE" | (echo "$(head -1 "$APPT_FILE")"; cat) | column -t -s,
      ;;
    2)
      read -p "Start date (YYYY-MM-DD): " start_date
      read -p "End date (YYYY-MM-DD): " end_date
      echo "🔍 Appointments between $start_date and $end_date:"
      awk -F',' -v start="$start_date" -v end="$end_date" 'NR==1 || ($3 >= start && $3 <= end)' "$APPT_FILE" | column -t -s,
      ;;
    3)
      read -p "Enter username: " username
      echo "🔍 Appointments involving '$username':"
      awk -F',' -v user="$username" 'NR==1 || $2==user || $5==user' "$APPT_FILE" | column -t -s,
      ;;
    4)
      echo "Status options: Pending, Approved, Rejected, Cancelled"
      read -p "Enter status: " status
      echo "🔍 Appointments with status '$status':"
      awk -F',' -v stat="$status" 'NR==1 || $8==stat' "$APPT_FILE" | column -t -s,
      ;;
    5)
      echo "Priority options: High, Medium, Low"
      read -p "Enter priority: " priority
      echo "🔍 Appointments with priority '$priority':"
      awk -F',' -v prio="$priority" 'NR==1 || $10==prio' "$APPT_FILE" | column -t -s,
      ;;
    6)
      read -p "Enter location: " location
      echo "🔍 Appointments at location '$location':"
      grep -i "$location" "$APPT_FILE" | (echo "$(head -1 "$APPT_FILE")"; cat) | column -t -s,
      ;;
    *)
      echo "❌ Invalid choice."
      ;;
  esac
}

# Dashboard with Statistics
view_dashboard() {
  echo "📊 Appointment Dashboard & Statistics"
  echo "========================================"
  
  local total_appointments=$(tail -n +2 "$APPT_FILE" | wc -l)
  local pending=$(awk -F',' '$8=="Pending"' "$APPT_FILE" | wc -l)
  local approved=$(awk -F',' '$8=="Approved"' "$APPT_FILE" | wc -l)
  local rejected=$(awk -F',' '$8=="Rejected"' "$APPT_FILE" | wc -l)
  
  local my_bookings=$(awk -F',' -v user="$current_user" '$2==user' "$APPT_FILE" | wc -l)
  local scheduled_with_me=$(awk -F',' -v user="$current_user" '$5==user' "$APPT_FILE" | wc -l)
  
  local today=$(date '+%Y-%m-%d')
  local today_appointments=$(awk -F',' -v today="$today" '$3==today' "$APPT_FILE" | wc -l)
  local upcoming=$(awk -F',' -v today="$today" '$3>today' "$APPT_FILE" | wc -l)
  
  echo "📈 Overall Statistics:"
  echo "   Total Appointments: $total_appointments"
  echo "   Pending: $pending | Approved: $approved | Rejected: $rejected"
  echo ""
  echo "👤 Your Statistics:"
  echo "   Appointments you booked: $my_bookings"
  echo "   Appointments scheduled with you: $scheduled_with_me"
  echo ""
  echo "📅 Today & Upcoming:"
  echo "   Today's appointments: $today_appointments"
  echo "   Future appointments: $upcoming"
  echo ""
  
  echo "🏆 Most Active Users:"
  tail -n +2 "$APPT_FILE" | cut -d',' -f2 | sort | uniq -c | sort -nr | head -5 | while read count user; do
    echo "   $user: $count appointments"
  done
  echo ""
  
  echo "📊 Priority Distribution:"
  echo "   High Priority: $(awk -F',' '$10=="High"' "$APPT_FILE" | wc -l)"
  echo "   Medium Priority: $(awk -F',' '$10=="Medium"' "$APPT_FILE" | wc -l)"
  echo "   Low Priority: $(awk -F',' '$10=="Low"' "$APPT_FILE" | wc -l)"
}

# Appointment Reminders
view_reminders() {
  echo "🔔 Appointment Reminders"
  local today=$(date '+%Y-%m-%d')
  local tomorrow=$(date -d "+1 day" '+%Y-%m-%d' 2>/dev/null || date '+%Y-%m-%d')
  
  echo "📅 Today's Appointments:"
  local today_count=0
  while IFS=',' read -r id booked_by date time with_whom client reason status duration priority location notes created; do
    if [[ "$date" == "$today" ]] && ([[ "$booked_by" == "$current_user" ]] || [[ "$with_whom" == "$current_user" ]]) && [[ "$status" == "Approved" ]]; then
      echo "   🕐 $time - $reason (with $([ "$booked_by" == "$current_user" ] && echo "$with_whom" || echo "$booked_by"))"
      today_count=$((today_count + 1))
    fi
  done < <(tail -n +2 "$APPT_FILE")
  
  if [ $today_count -eq 0 ]; then
    echo "   No appointments today."
  fi
  
  echo ""
  echo "📅 Tomorrow's Appointments:"
  local tomorrow_count=0
  while IFS=',' read -r id booked_by date time with_whom client reason status duration priority location notes created; do
    if [[ "$date" == "$tomorrow" ]] && ([[ "$booked_by" == "$current_user" ]] || [[ "$with_whom" == "$current_user" ]]) && [[ "$status" == "Approved" ]]; then
      echo "   🕐 $time - $reason (with $([ "$booked_by" == "$current_user" ] && echo "$with_whom" || echo "$booked_by"))"
      tomorrow_count=$((tomorrow_count + 1))
    fi
  done < <(tail -n +2 "$APPT_FILE")
  
  if [ $tomorrow_count -eq 0 ]; then
    echo "   No appointments tomorrow."
  fi
}

# User Profile Management
manage_profile() {
  echo "👤 User Profile Management"
  echo "Current Profile:"
  local profile=$(grep "^$current_user," "$USERS_FILE")
  echo "   Username: $current_user"
  echo "   Full Name: $current_name"
  echo "   Profession: $current_profession"
  
  if [[ $(echo "$profile" | grep -o ',' | wc -l) -ge 6 ]]; then
    local email=$(echo "$profile" | cut -d',' -f5)
    local phone=$(echo "$profile" | cut -d',' -f6)
    local timezone=$(echo "$profile" | cut -d',' -f7)
    echo "   Email: $email"
    echo "   Phone: $phone"
    echo "   Timezone: $timezone"
  fi
  
  echo ""
  echo "1. Change Password"
  echo "2. Update Profile Information"
  echo "3. Back to Main Menu"
  read -p "Choose option (1-3): " profile_choice
  
  case $profile_choice in
    1)
      read -p "Enter current password: " current_pass
      if ! grep -q "^$current_user,$current_pass," "$USERS_FILE"; then
        echo "❌ Incorrect current password."
        return
      fi
      read -p "Enter new password: " new_pass
      read -p "Confirm new password: " confirm_pass
      if [ "$new_pass" != "$confirm_pass" ]; then
        echo "❌ Passwords do not match."
        return
      fi
      
      # Update password in users file
      local temp_file=$(mktemp)
      while IFS=',' read -r username password full_name profession email phone timezone; do
        if [ "$username" == "$current_user" ]; then
          echo "$username,$new_pass,$full_name,$profession,$email,$phone,$timezone"
        else
          echo "$username,$password,$full_name,$profession,$email,$phone,$timezone"
        fi
      done < "$USERS_FILE" > "$temp_file" && mv "$temp_file" "$USERS_FILE"
      echo "✅ Password updated successfully."
      ;;
    2)
      echo "Updating profile information..."
      read -p "Full Name [$current_name]: " new_name
      read -p "Profession [$current_profession]: " new_profession
      read -p "Email: " new_email
      read -p "Phone: " new_phone
      read -p "Timezone: " new_timezone
      
      new_name=${new_name:-$current_name}
      new_profession=${new_profession:-$current_profession}
      
      # Update profile in users file
      local temp_file=$(mktemp)
      while IFS=',' read -r username password full_name profession email phone timezone; do
        if [ "$username" == "$current_user" ]; then
          echo "$username,$password,$new_name,$new_profession,$new_email,$new_phone,$new_timezone"
        else
          echo "$username,$password,$full_name,$profession,$email,$phone,$timezone"
        fi
      done < "$USERS_FILE" > "$temp_file" && mv "$temp_file" "$USERS_FILE"
      
      current_name="$new_name"
      current_profession="$new_profession"
      echo "✅ Profile updated successfully."
      ;;
  esac
}

# View and Manage Notifications
view_notifications() {
  echo "🔔 Notifications"
  local notifications=$(grep ",$current_user," "$NOTIFICATIONS_FILE")
  
  if [ -z "$notifications" ]; then
    echo "No notifications."
    return
  fi
  
  echo "Your notifications:"
  echo "$notifications" | while IFS=',' read -r id username appointment_id message type timestamp read_status; do
    local status_icon="📬"
    if [ "$read_status" == "true" ]; then
      status_icon="📭"
    fi
    echo "$status_icon [$timestamp] $message"
  done
  
  echo ""
  read -p "Mark all as read? (y/n): " mark_read
  if [[ "$mark_read" =~ ^[Yy]$ ]]; then
    # Mark all notifications as read
    local temp_file=$(mktemp)
    while IFS=',' read -r id username appointment_id message type timestamp read_status; do
      if [ "$username" == "$current_user" ]; then
        echo "$id,$username,$appointment_id,$message,$type,$timestamp,true"
      else
        echo "$id,$username,$appointment_id,$message,$type,$timestamp,$read_status"
      fi
    done < "$NOTIFICATIONS_FILE" > "$temp_file" && mv "$temp_file" "$NOTIFICATIONS_FILE"
    echo "✅ All notifications marked as read."
  fi
}

# Enhanced Cancel your own appointment
cancel_appointment() {
  echo "🗑️ Cancel Appointment"
  echo "Your booked appointments:"
  
  local user_appointments=""
  while IFS=',' read -r id booked_by date time with_whom client reason status duration priority location notes created; do
    if [ "$booked_by" == "$current_user" ] && [ "$status" != "Cancelled" ]; then
      if [ -z "$user_appointments" ]; then
        user_appointments="$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created"
      else
        user_appointments="$user_appointments"$'\n'"$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created"
      fi
    fi
  done < <(tail -n +2 "$APPT_FILE")
  
  if [ -z "$user_appointments" ]; then
    echo "No appointments available to cancel."
    return
  fi
  
  (head -1 "$APPT_FILE"; echo "$user_appointments") | column -t -s,
  
  read -p "Enter Appointment ID to cancel: " cancel_id
  
  # Verify the appointment belongs to the user and isn't already cancelled
  local appointment_line=$(grep "^$cancel_id,$current_user," "$APPT_FILE")
  if [ -z "$appointment_line" ]; then
    echo "❌ You can only cancel appointments you booked."
    return
  fi
  
  local status=$(echo "$appointment_line" | cut -d',' -f8)
  if [ "$status" == "Cancelled" ]; then
    echo "❌ This appointment is already cancelled."
    return
  fi
  
  read -p "Are you sure you want to cancel this appointment? (y/n): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Cancellation aborted."
    return
  fi
  
  # Update appointment status to Cancelled instead of deleting
  local temp_file=$(mktemp)
  while IFS=',' read -r id booked_by date time with_whom client reason appt_status duration priority location notes created; do
    if [ "$id" == "$cancel_id" ] && [ "$booked_by" == "$current_user" ]; then
      echo "$id,$booked_by,$date,$time,$with_whom,$client,$reason,Cancelled,$duration,$priority,$location,$notes,$created"
    else
      echo "$id,$booked_by,$date,$time,$with_whom,$client,$reason,$appt_status,$duration,$priority,$location,$notes,$created"
    fi
  done < "$APPT_FILE" > "$temp_file" && mv "$temp_file" "$APPT_FILE"
  
  # Get the person who was booked with for notification
  local with_whom=$(echo "$appointment_line" | cut -d',' -f5)
  add_notification "$with_whom" "$cancel_id" "Appointment cancelled by $current_name on $date at $time" "APPOINTMENT_CANCELLED"
  
  echo "🗑️ Appointment $cancel_id cancelled successfully."
}

# Enhanced Approve or Reject appointments scheduled with you
approve_reject_appointments() {
  echo "📝 Manage Pending Appointments Scheduled With You"
  local pending_apps=""
  
  while IFS=',' read -r id booked_by date time with_whom client reason status duration priority location notes created; do
    if [ "$with_whom" == "$current_user" ] && [ "$status" == "Pending" ]; then
      if [ -z "$pending_apps" ]; then
        pending_apps="$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created"
      else
        pending_apps="$pending_apps"$'\n'"$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created"
      fi
    fi
  done < <(tail -n +2 "$APPT_FILE")
  
  if [ -z "$pending_apps" ]; then
    echo "No pending appointments to approve or reject."
    return
  fi

  (head -1 "$APPT_FILE"; echo "$pending_apps") | column -t -s,

  echo ""
  echo "Options:"
  echo "1. Approve/Reject specific appointment"
  echo "2. Bulk approve all"
  echo "3. Bulk reject all"
  read -p "Choose option (1-3): " bulk_choice
  
  case $bulk_choice in
    1)
      read -p "Enter Appointment ID to approve/reject: " app_id
      if [ -z "$app_id" ]; then
        echo "No ID entered."
        return
      fi
      
      read -p "Approve (A) or Reject (R)? " decision
      decision=$(echo "$decision" | tr '[:upper:]' '[:lower:]')
      
      if [ "$decision" == "a" ]; then
        status="Approved"
      elif [ "$decision" == "r" ]; then
        status="Rejected"
      else
        echo "❌ Invalid choice."
        return
      fi
      
      # Check for conflicts if approving
      if [ "$status" == "Approved" ]; then
        local appointment_line=$(grep "^$app_id," "$APPT_FILE")
        local date=$(echo "$appointment_line" | cut -d',' -f3)
        local time=$(echo "$appointment_line" | cut -d',' -f4)
        local duration=$(echo "$appointment_line" | cut -d',' -f9)
        
        if ! check_conflicts "$current_user" "$date" "$time" "$duration" "$app_id"; then
          echo "⚠️ Conflict detected! You have overlapping appointments."
          echo "Do you still want to approve? (y/n)"
          read -p "Answer: " force_approve
          if [[ ! "$force_approve" =~ ^[Yy]$ ]]; then
            echo "❌ Approval cancelled."
            return
          fi
        fi
      fi
      
      update_appointment_status "$app_id" "$status"
      ;;
    2)
      read -p "Are you sure you want to approve ALL pending appointments? (y/n): " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$pending_apps" | while IFS=',' read -r id rest; do
          update_appointment_status "$id" "Approved"
        done
        echo "✅ All pending appointments approved."
      fi
      ;;
    3)
      read -p "Are you sure you want to reject ALL pending appointments? (y/n): " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$pending_apps" | while IFS=',' read -r id rest; do
          update_appointment_status "$id" "Rejected"
        done
        echo "✅ All pending appointments rejected."
      fi
      ;;
    *)
      echo "❌ Invalid choice."
      ;;
  esac
}

# Helper function to update appointment status
update_appointment_status() {
  local app_id=$1
  local new_status=$2
  
  local temp_file=$(mktemp)
  local updated=0
  
  while IFS=',' read -r id booked_by date time with_whom client reason status duration priority location notes created; do
    if [ "$id" == "$app_id" ] && [ "$with_whom" == "$current_user" ]; then
      echo "$id,$booked_by,$date,$time,$with_whom,$client,$reason,$new_status,$duration,$priority,$location,$notes,$created"
      updated=1
      
      # Add notification to the person who booked
      add_notification "$booked_by" "$app_id" "Your appointment on $date at $time has been $new_status" "APPOINTMENT_$new_status"
    else
      echo "$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created"
    fi
  done < "$APPT_FILE" > "$temp_file" && mv "$temp_file" "$APPT_FILE"

  if [ $updated -eq 1 ]; then
    echo "✅ Appointment $app_id marked as $new_status."
  else
    echo "❌ No matching appointment found."
  fi
}

# Export appointments to different formats
export_appointments() {
  echo "📤 Export Appointments"
  echo "1. Export as CSV"
  echo "2. Export as Text Report"
  echo "3. Export upcoming appointments only"
  echo "4. Export your booked appointments"
  read -p "Choose export type (1-4): " export_type
  
  local filename=""
  local today=$(date '+%Y-%m-%d')
  
  case $export_type in
    1)
      filename="appointments_export_$(date '+%Y%m%d_%H%M%S').csv"
      cp "$APPT_FILE" "$filename"
      echo "✅ All appointments exported to $filename"
      ;;
    2)
      filename="appointments_report_$(date '+%Y%m%d_%H%M%S').txt"
      {
        echo "==================================="
        echo "   APPOINTMENT SCHEDULER REPORT"
        echo "   Generated on: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "==================================="
        echo ""
        
        echo "SUMMARY:"
        echo "--------"
        echo "Total Appointments: $(tail -n +2 "$APPT_FILE" | wc -l)"
        echo "Pending: $(awk -F',' '$8=="Pending"' "$APPT_FILE" | wc -l)"
        echo "Approved: $(awk -F',' '$8=="Approved"' "$APPT_FILE" | wc -l)"
        echo "Rejected: $(awk -F',' '$8=="Rejected"' "$APPT_FILE" | wc -l)"
        echo ""
        
        echo "ALL APPOINTMENTS:"
        echo "-----------------"
        column -t -s, < "$APPT_FILE"
      } > "$filename"
      echo "✅ Appointment report exported to $filename"
      ;;
    3)
      filename="upcoming_appointments_$(date '+%Y%m%d_%H%M%S').csv"
      {
        head -1 "$APPT_FILE"
        awk -F',' -v today="$today" '$3 >= today' "$APPT_FILE"
      } > "$filename"
      echo "✅ Upcoming appointments exported to $filename"
      ;;
    4)
      filename="my_appointments_$(date '+%Y%m%d_%H%M%S').csv"
      {
        head -1 "$APPT_FILE"
        awk -F',' -v user="$current_user" '$2 == user' "$APPT_FILE"
      } > "$filename"
      echo "✅ Your appointments exported to $filename"
      ;;
    *)
      echo "❌ Invalid choice."
      return
      ;;
  esac
  
  echo "📁 File location: $(pwd)/$filename"
}

# Import appointments from CSV
import_appointments() {
  echo "📥 Import Appointments"
  read -p "Enter CSV filename to import: " import_file
  
  if [ ! -f "$import_file" ]; then
    echo "❌ File not found: $import_file"
    return
  fi
  
  echo "⚠️ Warning: This will add appointments from the CSV file."
  echo "Make sure the CSV format matches: ID,BookedBy,Date,Time,WithWhom,ClientName,Reason,Status,Duration,Priority,Location,Notes,CreatedDate"
  read -p "Continue? (y/n): " confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Import cancelled."
    return
  fi
  
  local imported=0
  local skipped=0
  
  while IFS=',' read -r id booked_by date time with_whom client reason status duration priority location notes created; do
    # Skip header and empty lines
    if [[ "$id" == "ID" ]] || [[ -z "$id" ]]; then
      continue
    fi
    
    # Check if appointment ID already exists
    if grep -q "^$id," "$APPT_FILE"; then
      echo "⚠️ Skipping appointment ID $id (already exists)"
      skipped=$((skipped + 1))
      continue
    fi
    
    # Validate users exist
    if ! grep -q "^$booked_by," "$USERS_FILE"; then
      echo "⚠️ Skipping appointment ID $id (user $booked_by not found)"
      skipped=$((skipped + 1))
      continue
    fi
    
    if ! grep -q "^$with_whom," "$USERS_FILE"; then
      echo "⚠️ Skipping appointment ID $id (user $with_whom not found)"
      skipped=$((skipped + 1))
      continue
    fi
    
    # Add the appointment
    echo "$id,$booked_by,$date,$time,$with_whom,$client,$reason,$status,$duration,$priority,$location,$notes,$created" >> "$APPT_FILE"
    imported=$((imported + 1))
    
  done < <(tail -n +2 "$import_file")
  
  echo "✅ Import completed: $imported appointments imported, $skipped skipped."
}

# Check user availability for a specific time period
check_availability() {
  echo "🕐 Check User Availability"
  
  echo "Available users:"
  cut -d',' -f1,3,4 "$USERS_FILE" | tail -n +2 | column -t -s,
  
  read -p "Enter username to check: " check_user
  if ! grep -q "^$check_user," "$USERS_FILE"; then
    echo "❌ User not found."
    return
  fi
  
  read -p "Enter date (YYYY-MM-DD): " check_date
  if ! validate_date "$check_date"; then
    echo "❌ Invalid date format."
    return
  fi
  
  echo "📅 Availability for $check_user on $check_date:"
  echo "Busy Times:"
  
  local has_appointments=false
  while IFS=',' read -r id booked_by date time with_whom client reason status duration priority location notes created; do
    if [[ "$date" == "$check_date" ]] && ([[ "$booked_by" == "$check_user" ]] || [[ "$with_whom" == "$check_user" ]]) && [[ "$status" == "Approved" ]]; then
      local end_time_minutes=$(($(time_to_minutes "$time") + duration))
      local end_hour=$((end_time_minutes / 60))
      local end_minute=$((end_time_minutes % 60))
      local end_time=$(printf "%02d:%02d" $end_hour $end_minute)
      echo "   🔴 $time - $end_time ($reason)"
      has_appointments=true
    fi
  done < <(tail -n +2 "$APPT_FILE")
  
  if [ "$has_appointments" == "false" ]; then
    echo "   ✅ No appointments scheduled - fully available"
  fi
  
  echo ""
  echo "Suggested Available Slots (1-hour duration):"
  local slot_count=0
  for hour in {9..17}; do
    local test_time=$(printf "%02d:00" $hour)
    if check_conflicts "$check_user" "$check_date" "$test_time" "60"; then
      echo "   ✅ $test_time - $(printf "%02d:00" $((hour + 1)))"
      slot_count=$((slot_count + 1))
    fi
  done
  
  if [ $slot_count -eq 0 ]; then
    echo "   ❌ No available 1-hour slots found"
  fi
}

# Generate appointment history report
appointment_history() {
  echo "📚 Appointment History Report"
  echo "1. Personal history (your appointments)"
  echo "2. All appointments history"
  echo "3. Cancelled appointments"
  echo "4. Monthly summary"
  read -p "Choose report type (1-4): " history_type
  
  local today=$(date '+%Y-%m-%d')
  
  case $history_type in
    1)
      echo "📋 Your Appointment History:"
      echo "Appointments you booked:"
      awk -F',' -v user="$current_user" -v today="$today" '$2 == user && $3 < today' "$APPT_FILE" | \
        sort -t',' -k3,3 -k4,4 | column -t -s,
      echo ""
      echo "Appointments scheduled with you:"
      awk -F',' -v user="$current_user" -v today="$today" '$5 == user && $3 < today' "$APPT_FILE" | \
        sort -t',' -k3,3 -k4,4 | column -t -s,
      ;;
    2)
      echo "📋 Complete Appointment History:"
      awk -F',' -v today="$today" 'NR==1 || $3 < today' "$APPT_FILE" | \
        sort -t',' -k3,3 -k4,4 | column -t -s,
      ;;
    3)
      echo "📋 Cancelled Appointments:"
      awk -F',' '$8 == "Cancelled"' "$APPT_FILE" | column -t -s,
      ;;
    4)
      read -p "Enter month (YYYY-MM): " month
      echo "📋 Monthly Summary for $month:"
      awk -F',' -v month="$month" 'NR==1 || $3 ~ "^" month' "$APPT_FILE" | column -t -s,
      echo ""
      echo "Statistics for $month:"
      local month_total=$(awk -F',' -v month="$month" '$3 ~ "^" month' "$APPT_FILE" | wc -l)
      local month_approved=$(awk -F',' -v month="$month" '$3 ~ "^" month && $8 == "Approved"' "$APPT_FILE" | wc -l)
      local month_pending=$(awk -F',' -v month="$month" '$3 ~ "^" month && $8 == "Pending"' "$APPT_FILE" | wc -l)
      local month_rejected=$(awk -F',' -v month="$month" '$3 ~ "^" month && $8 == "Rejected"' "$APPT_FILE" | wc -l)
      echo "Total: $month_total | Approved: $month_approved | Pending: $month_pending | Rejected: $month_rejected"
      ;;
  esac
}

# Enhanced Main menu after login
main_menu() {
  while true; do
    echo
    echo "==============================================="
    echo "   🗓️  ENHANCED APPOINTMENT SCHEDULER"
    echo "   Welcome, $current_name ($current_profession)"
    echo "==============================================="
    echo
    echo "📅 APPOINTMENT MANAGEMENT:"
    echo "  1.  Book New Appointment"
    echo "  2.  View Your Booked Appointments (Enhanced)"
    echo "  3.  View Appointments Scheduled With You (Enhanced)"
    echo "  4.  Cancel Your Appointment"
    echo "  5.  Approve/Reject Pending Appointments"
    echo
    echo "🔍 SEARCH & ANALYTICS:"
    echo "  6.  Search & Filter Appointments"
    echo "  7.  Dashboard & Statistics"
    echo "  8.  Appointment Reminders"
    echo
    echo "👤 PROFILE & NOTIFICATIONS:"
    echo "  9.  Manage User Profile"
    echo "  10. View Notifications"
    echo
    echo "📤 DATA MANAGEMENT:"
    echo "  11. Export Appointments"
    echo "  12. Import Appointments"
    echo
    echo "� ADVANCED FEATURES:"
    echo "  13. Check User Availability"
    echo "  14. Appointment History Reports"
    echo
    echo "�🚪 SYSTEM:"
    echo "  15. Logout"
    echo
    read -p "Enter your choice (1-15): " choice
    
    case $choice in
      1) book_appointment ;;
      2) view_booked ;;
      3) view_your_schedule ;;
      4) cancel_appointment ;;
      5) approve_reject_appointments ;;
      6) search_appointments ;;
      7) view_dashboard ;;
      8) view_reminders ;;
      9) manage_profile ;;
      10) view_notifications ;;
      11) export_appointments ;;
      12) import_appointments ;;
      13) check_availability ;;
      14) appointment_history ;;
      15) echo "👋 Logged out successfully."; break ;;
      *) echo "❌ Invalid choice. Please enter a number between 1-15." ;;
    esac
    
    echo
    read -p "Press ENTER to continue..."
  done
}

# Enhanced Login/Register menu
login_menu() {
  while true; do
    echo
    echo "=================================================="
    echo "   🗓️  ENHANCED APPOINTMENT SCHEDULER SYSTEM"
    echo "   Advanced Features & Professional Management"
    echo "=================================================="
    echo
    echo "✨ New Features Include:"
    echo "   • Advanced search & filtering"
    echo "   • Statistics dashboard"
    echo "   • Recurring appointments" 
    echo "   • Conflict detection"
    echo "   • Priority levels"
    echo "   • Export/Import functionality"
    echo "   • Notification system"
    echo "   • Profile management"
    echo
    echo "🚪 AUTHENTICATION:"
    echo "   1. Register New Account"
    echo "   2. Login to Existing Account"
    echo "   3. Exit System"
    echo
    read -p "Choose your option (1-3): " option
    case $option in
      1) register ;;
      2) login && main_menu ;;
      3) echo "👋 Thank you for using Enhanced Appointment Scheduler!"; exit 0 ;;
      *) echo "❌ Invalid choice. Please enter 1, 2, or 3." ;;
    esac
  done
}

# Start the program
login_menu
