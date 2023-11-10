import serial

# Open the serial port (adjust the port name and baud rate)
ser = serial.Serial(port='COM5', baudrate=115200)  # Replace 'COMx' with the actual port name

while True:
    #Read data from the DE1 board
    data = ser.readline()
    valueInString=str(data,'UTF-8')
    print(valueInString)
    print('Data Recieved: ')
    print(data.decode('utf-8'))  # Decode the received bytes to a string

    # Close the serial port when done
    #ser.close()
