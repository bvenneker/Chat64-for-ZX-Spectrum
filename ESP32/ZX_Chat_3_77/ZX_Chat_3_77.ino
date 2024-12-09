#include <Preferences.h>
#include <ArduinoJson.h>
#include "CH9350_USBKEY.h"
#include "common.h"
#include "utils.h"
#include "wifi_core.h"
#include "prgfile.h"
Preferences settings;

// About the regID (registration id)
// A user needs to register at https://www.chat64.nl
// they will receive a registration_id via email.
// that number needs to be filled in on the account setup page on the ZX Spectrum
// now the cartridge is registered and the administrator has a way to block the user
// the user can not register again with the same email address if they are blocked

// ********************************
// **     Global Variables       **
// ********************************
String configured = "empty";  // do not change this!

String urgentMessage = "";
int wificonnected = -1;
char regStatus = 'u';
volatile bool dataFromBus = false;
volatile bool io2 = false;
char inbuffer[250];  // a character buffer for incomming data
int inbuffersize = 0;
char outbuffer[250];  // a character buffer for outgoing data
int outbuffersize = 0;
char textsize = 0;
int it = 0;
int doReset = 0;
volatile byte ch = 0;
TaskHandle_t Task1;
byte send_error = 0;
int userpageCount = 0;
char multiMessageBufferPub[3500];
char multiMessageBufferPriv[3500];
unsigned long first_check = 0;
bool invert_reset_signal = false;
bool invert_nmi_signal = false;

WiFiCommandMessage commandMessage;
WiFiResponseMessage responseMessage;

// ********************************
// **        OUTPUTS             **
// ********************************
// see http://www.bartvenneker.nl/index.php?art=0030
// for usable io pins!

#define oBusRST GPIO_NUM_21  // reset signal to Bus
#define oBusNMI GPIO_NUM_32  // non-maskable interrupt signal to Bus
#define CLED GPIO_NUM_4      // led on cartridge
#define sclk1 GPIO_NUM_27    // serial clock signal to the shift register
#define RCLK GPIO_NUM_14     // RCLK signal to the 165 shift register
#define sclk2 GPIO_NUM_25    // serial clock signal to the shift register
#define oSdata GPIO_NUM_33

// ********************************
// **        INPUTS             **
// ********************************
#define resetSwitch GPIO_NUM_15  // this pin outputs PWM signal at boot
#define BusIO1 GPIO_NUM_22
#define sdata GPIO_NUM_34
#define BusIO2 GPIO_NUM_13  

//IOs for CH9350 used on ESP32
#define RXKEY GPIO_NUM_16
#define TXKEY GPIO_NUM_17

USB9350_KeyBoard USBKeyBoard;  //Create an Instance for Keyboard

// *************************************************
// Interrupt routine for IO1
// *************************************************
void IRAM_ATTR isr_io1() {

  // This signal goes LOW when the computer writes to (or reads from) the IO1 address space
  // In our case the ZX Spectrum only WRITES the IO1 address space, so ESP32 can read the data.
  ready_to_receive(false);
  ch = 0;
  ch = shiftIn(sdata, sclk1, MSBFIRST);
  dataFromBus = true;
}

// *************************************************
// Interrupt routine for IO2
// *************************************************
void IRAM_ATTR isr_io2() {
  // This signal goes LOW when the computer uses the output or input command in our address space
  io2 = true;
}

// *************************************************
// Interrupt routine, to restart the esp32
// *************************************************
void IRAM_ATTR isr_reset() {
  reboot();
}

void reboot() {
  ESP.restart();
}

void create_Task_WifiCore() {
  // we create a task for the second (unused) core of the esp32
  // this task will communicate with the web site while the other core
  // is busy talking to the Bus
  xTaskCreatePinnedToCore(
    WifiCoreLoop, /* Function to implement the task */
    "Task1",      /* Name of the task */
    10000,        /* Stack size in words */
    NULL,         /* Task input parameter */
    0,            /* Priority of the task */
    &Task1,       /* Task handle. */
    0);           /* Core where the task should run */
}
// *************************************************
//  SETUP
// *************************************************
void setup() {
  Serial.begin(115200);
  Serial2.begin(115200, SERIAL_8N1, RXKEY, TXKEY);  
  USBKeyBoard.begin(Serial2);

  commandBuffer = xMessageBufferCreate(sizeof(commandMessage) + sizeof(size_t));
  responseBuffer = xMessageBufferCreate(sizeof(responseMessage) + sizeof(size_t));

  create_Task_WifiCore();

  // get the wifi mac address, this is used to identify the cartridge.
  commandMessage.command = GetWiFiMacAddressCommand;
  xMessageBufferSend(commandBuffer, &commandMessage, sizeof(commandMessage), portMAX_DELAY);
  xMessageBufferReceive(responseBuffer, &responseMessage, sizeof(responseMessage), portMAX_DELAY);
  macaddress = responseMessage.response.str;
  macaddress.replace(":", "");
  macaddress.toLowerCase();
  macaddress = macaddress.substring(4);

  // add a checksum to the mac address.
  byte data[4];
  int i = 0;
  for (unsigned int t = 0; t < macaddress.length(); t = t + 2) {
    String p = macaddress.substring(t, t + 2);
    char n[3];
    p.toCharArray(n, 3);
    byte f = x2i(n);
    data[i++] = f;
  }
  String crc8 = String(checksum(data, 4), HEX);

  if (crc8.length() == 1) crc8 = "0" + crc8;
  macaddress += crc8;

  // init settings object to store settings in the eeprom
  settings.begin("mysettings", false);
  //
  doReset = settings.getInt("doReset", 0);
  // get the configured status from the eeprom
  configured = settings.getString("configured", "empty");

  // get the registration id from the eeprom
  regID = settings.getString("regID", "unregistered!");

  // get the nick name from the eeprom
  myNickName = settings.getString("myNickName", "empty");

  // get the last known message id (only the private is stored in eeprom)
  lastprivmsg = settings.getULong("lastprivmsg", 1);

  // get Chatserver ip/fqdn from eeprom
  server = settings.getString("server", "www.chat64.nl");

  ssid = settings.getString("ssid", "empty");  // get WiFi credentials and Chatserver ip/fqdn from eeprom
  password = settings.getString("password", "empty");
  timeoffset = settings.getString("timeoffset", "+0");  // get the time offset from the eeprom

  settings.putInt("invRST", (int)invert_reset_signal);  // for future fuctionality
  settings.putInt("invNMI", (int)invert_nmi_signal);    // for future fuctionality

  settings.end();

  // define inputs
  pinMode(sdata, INPUT);
  pinMode(BusIO1, INPUT_PULLDOWN);
  pinMode(BusIO2, INPUT_PULLUP);
  pinMode(resetSwitch, INPUT_PULLUP);

  // define interrupts
  attachInterrupt(BusIO1, isr_io1, RISING);          // interrupt for io1, Bus writes data to io1 address space
  attachInterrupt(BusIO2, isr_io2, FALLING);         // interrupt for io2, Bus reads
  attachInterrupt(resetSwitch, isr_reset, FALLING);  // interrupt for reset button

  // define outputs
  pinMode(oSdata, OUTPUT);
  pinMode(CLED, OUTPUT);
  digitalWrite(CLED, LOW);

  ready_to_receive(false);
  pinMode(oBusRST, OUTPUT);
  pinMode(oBusNMI, OUTPUT);

  digitalWrite(oBusRST, invert_reset_signal);
  digitalWrite(oBusNMI, invert_nmi_signal);

  pinMode(RCLK, OUTPUT);
  digitalWrite(RCLK, LOW);  // must be low  
  pinMode(sclk1, OUTPUT);
  digitalWrite(sclk1, LOW);  //data shifts to serial data output on the transition from low to high.
  pinMode(sclk2, OUTPUT);
  digitalWrite(sclk2, LOW);  //data shifts to serial data output on the transition from low to high.


  //ready_to_receive(false);
  if (doReset != 157) {
    // Reset the Bus, toggle the output pin
    digitalWrite(oBusRST, !invert_reset_signal);
    delay(250);
    digitalWrite(oBusRST, invert_reset_signal);

  } else {
    settings.begin("mysettings", false);
    settings.putInt("doReset", 0);

    messageIds[0] = settings.getULong("lastPubMessage", 0);
    messageIds[1] = settings.getULong("lastPrivMessage", 0);

    settings.end();
    pastMatrix = true;
  }
  settings.begin("mysettings", false);
  settings.putInt("doReset", 0);
  settings.end();




  // load the prg file
  if (!pastMatrix) loadPrgfile();

  // start wifi
  commandMessage.command = WiFiBeginCommand;
  xMessageBufferSend(commandBuffer, &commandMessage, sizeof(commandMessage), portMAX_DELAY);

  //commandMessage.command = GetWiFiLocalIpCommand;
  //xMessageBufferSend(commandBuffer, &commandMessage, sizeof(commandMessage), portMAX_DELAY);
  //xMessageBufferReceive(responseBuffer, &responseMessage, sizeof(responseMessage), portMAX_DELAY);
  //String localIp = responseMessage.response.str;
  // check if we are connected to wifi
  if (isWifiCoreConnected) {
    wificonnected = 1;
  }

}  // end of setup

// ******************************************************************************
// Main loop
// ******************************************************************************
int pos1 = 0;
int pos0 = 0;
bool wifiError = false;
void loop() {
  
  digitalWrite(CLED, isWifiCoreConnected);
  ready_to_receive(true);

  if (isWifiCoreConnected and wificonnected == -1) wificonnected = 1;  // only set wificonnected if it has not been set

  if (dataFromBus) {
    dataFromBus = false;
    ready_to_receive(false);  // flow controll

#ifdef debug
    //Serial.printf("incomming command: %d\n", ch);
#endif

    //
    if (wifiError and isWifiCoreConnected) {
      urgentMessage = "[grn]Wifi connection restored.       ";
      wifiError = false;
      wificonnected = 1;
    }

    // generate an error if wifi connection drops
    if (wificonnected == 1 && !isWifiCoreConnected) {
      digitalWrite(CLED, LOW);
      wificonnected = 0;
      myLocalIp = "0.0.0.0";
      urgentMessage = "[red]Error in WiFi connection.       ";
      wifiError = true;
    }

    // 254 = Computer triggers call to the website for new public message
    // 253 = new chat message from Computer to database
    // 252 = Computer sends the new wifi network name (ssid) AND password AND time offset
    // 251 = Computer ask for the current wifi ssid,password and time offset
    // 250 = Computer ask for the first full page of messages (during startup)
    // 249 = get result of last send action (253)
    // 248 = Computer ask for the wifi connection status
    // 247 = Computer triggers call to the website for new private message
    // 246 = set chatserver ip/fqdn
    // 245 = check if the esp is connected at all, or are we running in simulation mode?
    // 244 = reset to factory defaults
    // 243 = Computer ask for the mac address, registration id, nickname and regstatus
    // 242 = get senders nickname of last private message.
    // 241 = get the number of unread private messages
    // 240 = Computer sends the new registration id and nickname to ESP32
    // 239 = Computer asks if updated firmware is available
    // 238 = Computer triggers call to the chatserver to test connectivity
    // 237 = get chatserver connectivity status
    // 236 = Computer asks for the server configuration status and servername
    // 235 = Computer sends server configuration status
    // 234 = get user list first page
    // 233 = get user list next page
    // 228 = debug purposes
    // 128 = end marker, ignore

    switch (ch) {
      case 254:
        {
          // ------------------------------------------------------------------------------
          // start byte 254 = Computer triggers call to the website for new public message
          // ------------------------------------------------------------------------------
          if (first_check == 0) first_check = millis();
          pastMatrix=true;
          // send urgent messages first
          doUrgentMessage();
          // if the user list is empty, get the list
          // also refresh the userlist when we switch from public to private messaging and vice versa
          if (users.length() < 1 or msgtype != "public") updateUserlist = true;
          msgtype = "public";

          // do we have any messages in the page buffer?
          // find the first '{' in the page buffer
          int p = 0;
          char cc = 0;
          bool found = false;
          // find first {
          while (cc != '{' and p < 10) {
            cc = multiMessageBufferPub[pos0++];

            p++;
          }
          // fill buffer until we find '}'
          if (cc == '{') {
            msgbuffer[0] = cc;
            found = true;
            getMessage = false;
            p = 1;
            while (cc != '}') {
              cc = multiMessageBufferPub[pos0++];
              // put this line into the msgbuffer buffer
              if (cc != 10) msgbuffer[p++] = cc;
            }
          }
          if (found) {
            found = false;
            Deserialize();
          } else {
            // clear the buffer
            for (int y = 0; y < 3500; y++) {
              multiMessageBufferPub[y] = 0;
            }
            pos0 = 0;
            getMessage = true;
          }

          if (haveMessage == 1) {
            translateZXMessage();
            // and send the outbuffer
            send_out_buffer_to_Bus();
            // store the new message id
            if (haveMessage == 1) {
              // store the new message id
              messageIds[0] = tempMessageIds[0];
            }
            haveMessage = 0;
          } else {  // no public messages :-(
            sendByte(128);
          }

          break;
        }

      case 253:
        {
          // ------------------------------------------------------------------------------
          // start byte 253 = new chat message from Computer to database
          // ------------------------------------------------------------------------------

          // we expect a chat message from the Computer
          receive_buffer_from_Bus(1);

          String toEncode = "";
          String RecipientName = "";
          int mstart = 0;
          String colorCode = "[145]";
          // Get the RecipientName
          // see if the message starts with '@'
          byte b = inbuffer[1];
          if (b == '@') {
            toEncode = "[" + String(translateColor(int(inbuffer[0]))) + "]";
            for (int x = 2; x < 15; x++) {
              byte b = inbuffer[x];              
              if (b != 32 and b!=',' and b!=':' and b!=';' and b!='.') {
                if (b < 127) {
                  RecipientName = (RecipientName + char(b));
                } else {
                  colorCode = "[" + String(translateColor(int(b))) + "]";
                }
              } else {
                mstart = x + 1;
                toEncode = toEncode + "@" + RecipientName + " " + colorCode;
                break;
              }
            }
          }
          byte lastb =0;
          for (int x = mstart; x < inbuffersize; x++) {
            byte b = inbuffer[x];
            lastb=b;
            if (b > 128) {
              toEncode = (toEncode + "[" + translateColor(int(inbuffer[x])) + "]");
            } else {
              //if (b==128) b=' ';
              toEncode = (toEncode + inbuffer[x]);
            }
          }
          mstart=mstart+3;
          if (lastb==128) toEncode.remove(toEncode.length()-1);

          if (RecipientName != "") {
            // is this a valid username?
            String test_name = RecipientName;
            if (test_name.endsWith(",") or test_name.endsWith(".")){
                test_name.remove(test_name.length()-1);

            }
            test_name.toLowerCase();
#ifdef debug
            Serial.print("known users: ");
            Serial.println(users);
            Serial.print("Name under test: ");
            Serial.println(test_name);
#endif
            if (users.indexOf(test_name + ';') >= 0) {
              // user exists
              msgtype = "private";
              pmSender = '@' + RecipientName;
            } else {
              // user does not exist
#ifdef debug
              Serial.println("Username not found in list");
#endif
              urgentMessage = "[red]System: Unknown user:" + RecipientName;
              send_error = 1;
              break;
            }
          } else {
            msgtype = "public";
          }
          toEncode.trim();
          int buflen = toEncode.length() + 1;
#ifdef debug
          Serial.print("Buffer len=");
          Serial.println(buflen - mstart);
          Serial.print("toEncode=");
          Serial.println(toEncode);
#endif

          if (buflen- mstart <= 7) break;   // this is an empty message, do not send it.

          char buff[buflen];
          toEncode.toCharArray(buff, buflen);

          
          String Encoded = my_base64_encode(buff, buflen);

          // Now send it with retry!
          bool sc = false;
          int retry = 0;
          while (sc == false and retry < 2) {
            sendingMessage = 1;
            commandMessage.command = SendMessageToServerCommand;
            Encoded.toCharArray(commandMessage.data.sendMessageToServer.encoded, sizeof(commandMessage.data.sendMessageToServer.encoded));
            RecipientName.toCharArray(commandMessage.data.sendMessageToServer.recipientName, sizeof(commandMessage.data.sendMessageToServer.recipientName));
            commandMessage.data.sendMessageToServer.retryCount = retry;
            xMessageBufferSend(commandBuffer, &commandMessage, sizeof(commandMessage), portMAX_DELAY);
            xMessageBufferReceive(responseBuffer, &responseMessage, sizeof(responseMessage), portMAX_DELAY);
            sc = responseMessage.response.boolean;
            // sending the message fails, take a short break and try again
            if (!sc) {
              delay(1000);
              retry = retry + 1;
            }
          }
          // if it still fails after a few retries, give us an error.
          if (!sc) {
            urgentMessage = "[yel]ERROR: sending the message";
            send_error = 1;
          } else {
            // No error, read the message back from the database to show it on screen
            sendingMessage = 0;
            getMessage = true;  // get the message we just inserted
          }
          break;
        }

      case 252:
        {
          // ------------------------------------------------------------------------------
          // 252 = Computer sends the new wifi network name (ssid) AND password AND time offset
          // ------------------------------------------------------------------------------
          receive_buffer_from_Bus(3);
          // inbuffer now contains "SSID password timeoffset"
          char bns[inbuffersize + 1];
          strncpy(bns, inbuffer, inbuffersize + 1);
          String ns = bns;

          ssid = getValue(ns, 129, 0);

          ssid.trim();
#ifdef debug
          Serial.print("SSID=");
          Serial.println(ssid);
#endif
          password = getValue(ns, 129, 1);
          password.trim();
#ifdef debug
          Serial.print("PASW=");
          Serial.println(password);
#endif
          timeoffset = getValue(ns, 129, 2);
          timeoffset.trim();
#ifdef debug
          Serial.print("GMT+=");
          Serial.println(timeoffset);
#endif

          settings.begin("mysettings", false);
          settings.putString("ssid", ssid);
          settings.putString("password", password);
          settings.putString("timeoffset", timeoffset);
          settings.end();
          commandMessage.command = WiFiBeginCommand;
          xMessageBufferSend(commandBuffer, &commandMessage, sizeof(commandMessage), portMAX_DELAY);
          break;
        }

      case 251:
        {
          // ------------------------------------------------------------------------------
          // start byte 251 = Computer ask for the current wifi ssid,password and time offset
          // ------------------------------------------------------------------------------
          send_String_to_Bus(ssid + char(129) + password + char(129) + timeoffset);
          break;
        }

      case 249:
        {
          // ------------------------------------------------------------------------------
          // start byte 249 = Computer asks if this is an existing user (for private chat)
          // ------------------------------------------------------------------------------
          sendByte(send_error);
          sendByte(128);
          send_error = 0;
          break;
        }

      case 248:
        {
          // ------------------------------------------------------------------------------
          // start byte 248 = Computer ask for the wifi connection status
          // ------------------------------------------------------------------------------

          if (!isWifiCoreConnected) {
            digitalWrite(CLED, LOW);
            sendByte(16);  // INK
            sendByte(2);   // RED
            send_String_to_Bus("Not Connected to Wifi");
          } else {
            wificonnected = 1;
            digitalWrite(CLED, HIGH);
            sendByte(16);  // INK
            sendByte(4);   // GREEN
            String wifi_status = "Connected, ip: " + myLocalIp;
            send_String_to_Bus(wifi_status);
            if (configured == "empty") {
              configured = "w";
              settings.begin("mysettings", false);
              settings.putString("configured", "w");
              settings.end();
            }
          }
          break;
        }

      case 247:
        {
          // ------------------------------------------------------------------------------
          // start byte 247 = Computer triggers call to the website for new private message
          // ------------------------------------------------------------------------------

          // send urgent messages first
          doUrgentMessage();
          // if the user list is empty, get the list
          // also refresh the userlist when we switch from public to private messaging and vice versa
          if (users.length() < 1 or msgtype != "private") updateUserlist = true;

          msgtype = "private";
          pmCount = 0;
          // do we have any messages in the page buffer?
          // find the first '{' in the page buffer
          int p = 0;
          char cc = 0;
          bool found = false;
          // find first {
          while (cc != '{' and p < 10) {
            cc = multiMessageBufferPriv[pos1++];
            p++;
          }
          // fill buffer until we find '}'
          if (cc == '{') {
            msgbuffer[0] = cc;
            found = true;
            getMessage = false;
            p = 1;
            while (cc != '}') {
              cc = multiMessageBufferPriv[pos1++];
              // put this line into the msgbuffer buffer
              if (cc != 10) msgbuffer[p++] = cc;
            }
          }
          if (found) {
            found = false;
            Deserialize();
          } else {
            // clear the buffer
            for (int y = 0; y < 3500; y++) {
              multiMessageBufferPriv[y] = 0;
            }
            pos1 = 0;
            getMessage = true;
          }
          if (haveMessage == 2) {
            translateZXMessage();
            // and send the outbuffer
            send_out_buffer_to_Bus();
            if (haveMessage == 2) {
              // store the new message id
              messageIds[1] = tempMessageIds[1];
              lastprivmsg = tempMessageIds[1];
              settings.begin("mysettings", false);
              settings.putULong("lastprivmsg", lastprivmsg);
              settings.end();
            }
            haveMessage = 0;
          } else {  // no private messages :-(
            sendByte(128);
            pmCount = 0;
          }

          break;
        }

      case 246:
        {
          // ------------------------------------------------------------------------------
          // start byte 246 = Computer sends a new chat server ip/fqdn
          // ------------------------------------------------------------------------------

          receive_buffer_from_Bus(1);

          char bns[inbuffersize + 1];
          strncpy(bns, inbuffer, inbuffersize + 1);
          String ns = bns;

          ns.remove(ns.length() - 1);
          ns.trim();
          server = ns;
          settings.begin("mysettings", false);
          settings.putString("server", ns);  // store the new server name in the eeprom settings
          settings.end();

          messageIds[0] = 0;
          messageIds[1] = 0;

          // we should also refresh the userlist
          users = "";

          break;
        }
      case 245:
        {
          // -----------------------------------------------------------------------------------------------------
          // start byte 245 = Computer checks if the Cartridge is connected at all.. or are we running in a simulator?
          // -----------------------------------------------------------------------------------------------------
          // receive the ROM version number
          receive_buffer_from_Bus(1);
          char bns[inbuffersize + 1];
          // filter out any unwanted bytes, keep only ./01234567890
          for (int k = 0; k < inbuffersize; k++) {
            if (inbuffer[k] < 45 or inbuffer[k] > 57) inbuffer[k] = 32;
          }
          strncpy(bns, inbuffer, inbuffersize + 1);
          String ns = bns;
          ns.replace(" ", "");
          romVersion = ns;
          // respond with byte 128 to tell the zxspectrum the cartridge is present
          sendByte(128);
          pastMatrix = true;
          getMessage = true;
#ifdef debug
          Serial.print("ROM Version=");
          Serial.println(romVersion);
          Serial.println("are we in the Matrix?");
#endif
          break;
        }
      case 244:
        {
          // ---------------------------------------------------------------------------------
          // start byte 244 = Computer sends the command to reset the cartridge to factory defaults
          // ---------------------------------------------------------------------------------
          // this will reset all settings
          receive_buffer_from_Bus(1);
          char bns[inbuffersize + 1];
          strncpy(bns, inbuffer, inbuffersize + 1);
          String ns = bns;
          if (ns.startsWith("RESET!")) {
            settings.begin("mysettings", false);
            settings.putString("regID", "unregistered!");
            settings.putString("myNickName", "empty");
            settings.putString("ssid", "empty");
            settings.putString("password", "empty");
            settings.putString("server", "empty");
            settings.putString("configured", "empty");
            settings.putString("timeoffset", "+0");
            settings.end();
            // now reset the esp
            reboot();
          }
          break;
        }

      case 243:
        {
          // ------------------------------------------------------------------------------
          // start byte 243 = Computer ask for the mac address, registration id, nickname and regstatus
          // ------------------------------------------------------------------------------
          commandMessage.command = GetRegistrationStatusCommand;
          xMessageBufferSend(commandBuffer, &commandMessage, sizeof(commandMessage), portMAX_DELAY);
          xMessageBufferReceive(responseBuffer, &responseMessage, sizeof(responseMessage), portMAX_DELAY);
          regStatus = responseMessage.response.str[0];
          send_String_to_Bus(macaddress + char(129) + regID + char(129) + myNickName + char(129) + regStatus);
          if (regStatus == 'r' and configured == "s") {
            configured = "d";
            settings.begin("mysettings", false);
            settings.putString("configured", "d");
            settings.end();
          }
          break;
        }
      case 242:
        {
          // ------------------------------------------------------------------------------
          // start byte 242 = Computer ask for the sender of the last private message
          // ------------------------------------------------------------------------------
          send_String_to_Bus(pmSender);
          break;
        }
      case 241:
        {
          // ------------------------------------------------------------------------------
          // start byte 241 = Computer asks for the number of unread private messages
          // ------------------------------------------------------------------------------
          if (pmCount > 10) pmCount = 10;
          String pm = String(pmCount);
          if (pmCount < 10) { pm = "0" + pm; }
          if (pmCount == 0) pm = "--";
          send_String_to_Bus(pm);  // then send the number of messages as a string
          break;
        }
      case 240:
        {
          // ------------------------------------------------------------------------------
          // start byte 240 = Computer sends the new registration id and nickname to ESP32
          // ------------------------------------------------------------------------------
          receive_buffer_from_Bus(2);
          // inbuffer now contains "registrationid nickname"
          char bns[inbuffersize + 1];
          strncpy(bns, inbuffer, inbuffersize + 1);
          String ns = bns;

          regID = getValue(ns, 129, 0);
          regID.trim();
#ifdef debug
          Serial.println(regID);
#endif
          if (regID.length() != 16) {
#ifdef debug
            Serial.println("Registration code length should be 16");
#endif
            break;
          }
          myNickName = getValue(ns, 129, 1);
          myNickName.trim();
          myNickName.replace(' ', '_');
#ifdef debug
          Serial.println(myNickName);
#endif

          settings.begin("mysettings", false);
          settings.putString("regID", regID);
          settings.putString("myNickName", myNickName);
          settings.end();
          break;
        }
      case 239:
        {
          String s = newVersions;
          if (millis() < (first_check + 10000)) s = "";
          send_String_to_Bus(s);

#ifdef debug
          if (s != "") {
            Serial.print("new version available! :");
            Serial.println(newVersions);
          } else {
            Serial.print("No update :");
            Serial.println(newVersions);
          }
#endif
          break;
        }
      case 238:
        {
          // ------------------------------------------------------------------------------
          // start byte 238 = Computer triggers call to the chatserver to test connectivity
          // ------------------------------------------------------------------------------
          ServerConnectResult = "Connection: Unknown, try again";
          commandMessage.command = ConnectivityCheckCommand;
          xMessageBufferSend(commandBuffer, &commandMessage, sizeof(commandMessage), portMAX_DELAY);
          break;
        }

      case 237:
        {
          // ------------------------------------------------------------------------------
          // start byte 237 = Computer triggers call to receive connection status
          // ------------------------------------------------------------------------------
          sendByte(16);  // send INK
          if (ResultColor == 149)
            sendByte(4);  // send green
          else
            sendByte(2);  // send RED

          send_String_to_Bus(ServerConnectResult);

          if ((configured == "w") and (ServerConnectResult == "Connected to chat server!")) {
            configured = "s";
            settings.begin("mysettings", false);
            settings.putString("configured", "s");
            settings.end();
          }
          break;
        }

      case 236:
        {
          // ------------------------------------------------------------------------------
          // start byte 236 = Computer asks for the server configuration status and servername
          // ------------------------------------------------------------------------------
          
#ifdef debug
          Serial.println("response 236 = " + configured + " " + server + " " + SwVersion);
#endif
          send_String_to_Bus(configured + char(129) + server + char(129) + SwVersion + char(129));
          break;
        }

      case 235:
        {
          // ------------------------------------------------------------------------------
          // start byte 235 = Computer sends configuration status
          // ------------------------------------------------------------------------------

          receive_buffer_from_Bus(1);
          char bns[inbuffersize + 1];
          strncpy(bns, inbuffer, inbuffersize + 1);
          String ns = bns;
          configured = ns;
          settings.begin("mysettings", false);
          settings.putString("configured", ns);
          settings.end();
          break;
        }
      case 234:
        {
          // Computer asks for user list, first page.
          // we send a max of 12 users in one long string
          userpageCount = 0;
          String ul1 = userPages[userpageCount];

          ul1.toCharArray(outbuffer, ul1.length() + 1);
          for (int x = 0; x < ul1.length(); x++) {
            if (outbuffer[x] == 130) outbuffer[x] = 0;
            sendByte(outbuffer[x]);
          }
          // all done, send end byte
          sendByte(128);
          userpageCount++;
          break;
        }
      case 233:
        {
          // Computer asks for user list, second or third page.
          // we send a max of 14 users in one long string
          String ul1 = userPages[userpageCount];
          //Serial.print("userpage ");
          //Serial.print(userpageCount);
          //Serial.print("= ");
          //Serial.println(ul1);
          ul1.toCharArray(outbuffer, ul1.length() + 1);
          for (int x = 0; x < ul1.length(); x++) {
            if (outbuffer[x] == 130) outbuffer[x] = 0;
            sendByte(outbuffer[x]);
          }
          // all done, send end byte
          sendByte(128);
          userpageCount++;
          if (userpageCount > 9) userpageCount = 8;
          break;
        }
      case 232:
        {  // do the update!
          receive_buffer_from_Bus(1);
          char bns[inbuffersize + 1];
          strncpy(bns, inbuffer, inbuffersize + 1);
          String ns = bns;
          if (ns.startsWith("UPDATE!")) {
            Serial.println("Update = GO <<<<");
            outByte(2);
            detachInterrupt(BusIO1);  // disable IO1 and IO2 interrupts
            detachInterrupt(BusIO2);  // disable IO1 and IO2 interrupts
            commandMessage.command = DoUpdateCommand;
            xMessageBufferSend(commandBuffer, &commandMessage, sizeof(commandMessage), portMAX_DELAY);
          }
          break;
        }
      case 228:
        {
          // ------------------------------------------------------------------------------
          // start byte 228 = Debug purposes
          // ------------------------------------------------------------------------------
          Serial.println("The code gets triggered");
          // your code here :-)
          sendByte(128);
          break;
        }
      default:
        {
          sendByte(128);
          break;
        }
    }  // end of case statements


  }  // end of "if (dataFromBus)"
  else {
    // No data from computer bus

    int key;
    key = USBKeyBoard.GetKey();
    if (key > 0) {
      //Serial.print(key);
      //Serial.print("=");
      key=translateKeystrokes(key);
      //Serial.println(key);
      int chi = Serial.read();
      sendByte(201);       
      delayMicroseconds(1500);       
      outByte(key);
      while (!io2) {}
    } 
  }
}  // end of main loop

int translateKeystrokes(int i){

  if (i == 241) return 199; // f1 = symbol shift - Q (go to main menu)
  if (i == 179) return 195; // controll S 
  if (i == 245) return 226; // f5 = symbol shift - A (private message)

            //   0   1   2   3   4   5   6   7   8   9
  int kkeys[]={  0,  0,  0,  0,  0,  0,  0,  0, 12,  9,  //   0 -  9
                10, 11, 12, 13, 14,195, 11, 10,  8,  9,  //  10 - 19
                20, 21, 22, 23, 24, 25, 26, 27, 28, 29,  //  20 - 29
                30, 31, 32, 33, 34, 35, 36, 37, 38, 39,  //  30 - 39
                40, 41, 42, 43, 44, 45, 46, 47, 48, 49,  //  40 - 49
                50, 51, 52, 53, 54, 55, 56, 57, 58, 59,  //  50 - 59
                60, 61, 62, 63, 64, 65, 66, 67, 68, 69,  //  60 - 69
                70, 71, 72, 73, 74, 75, 76, 77, 78, 79,  //  70 - 79
                80, 81, 82, 83, 84, 85, 86, 87, 88, 89,  //  80 - 89
                90, 91, 92, 93, 94, 95, 96, 97, 98, 99,  //  90 - 99
               100,101,102,103,104,105,106,107,108,109,  // 100 - 109
               110,111,112,113,114,115,116,117,118,119,  // 110 - 119
               120,121,122,123,124,125,126, 12,128,129   // 120 - 129
              };

  if (i>129) return i;
  return kkeys[i];
}
// ******************************************************************************
// void to set a byte in the 74ls595 shift register
// ******************************************************************************
void outByte(byte c) {
  digitalWrite(RCLK, LOW);
  shiftOut(oSdata, sclk2, MSBFIRST, c);
  digitalWrite(RCLK, HIGH);
}

// ******************************************************************************
// void: send a string to the Computer Bus
// ******************************************************************************
void send_String_to_Bus(String s) {

  outbuffersize = s.length() + 1;  // set outbuffer size
  //Serial.print("buffersize= ");
  //Serial.println(outbuffersize);
  s.toCharArray(outbuffer, outbuffersize);  // place the ssid in the output buffer
  send_out_buffer_to_Bus();                 // and send the buffer
}

// ******************************************************************************
// Send the content of the outbuffer to the Bus
// ******************************************************************************
void send_out_buffer_to_Bus() {
  // send the content of the outbuffer to the Bus
  for (int x = 0; x < outbuffersize - 1; x++) {
    //delayMicroseconds(100);
    sendByte(outbuffer[x]);
#ifdef debug
    Serial.print(outbuffer[x]);
#endif
  }
  // all done, send end byte
  sendByte(128);
  outbuffersize = 0;
#ifdef debug
  Serial.println();
#endif
}

// ******************************************************************************
// void: for debugging
// ******************************************************************************
void debug_print_inbuffer() {
  for (int x = 0; x < inbuffersize; x++) {
    char sw = screenCode_to_Ascii(inbuffer[x]);
    Serial.print(sw);
  }
}

// ******************************************************************************
//  void to receive characters from the Bus and store them in a buffer
// ******************************************************************************
void receive_buffer_from_Bus(int cnt) {

  // cnt is the number of transmissions we put into this buffer
  // This number is 1 most of the time
  // but in the configuration screens the Computer will send multiple items at once (like ssid and password)

  int i = 0;

  while (cnt > 0) {
    ready_to_receive(true);  // ready for next byte
    unsigned long timeOut = millis() + 500;

    while (dataFromBus == false) {
      delayMicroseconds(2);  // wait for next byte
      if (millis() > timeOut) {
        ch = 128;
        dataFromBus = true;
#ifdef debug
        Serial.println("Timeout in receive buffer");
#endif
      }
    }
    ready_to_receive(false);
    dataFromBus = false;
    inbuffer[i] = ch;
#ifdef debug
    Serial.print(char(ch));
#endif
    i++;
    if (i > 248) {  //this should never happen
#ifdef debug
      Serial.print("Error: inbuffer is about to flow over!");
#endif
      ch = 128;
      cnt = 1;
      break;
    }
    if (ch == 128) {
      cnt--;
      inbuffer[i] = 129;
      i++;
#ifdef debug
      Serial.println();
#endif
    }
  }
  i--;
  inbuffer[i] = 0;  // close the buffer
  inbuffersize = i;
#ifdef debug
      Serial.println();
#endif
}





// ******************************************************************************
// pull the NMI line low for a few microseconds
// ******************************************************************************
void triggerNMI() {

  // toggle NMI
  digitalWrite(oBusNMI, !invert_nmi_signal);
  delayMicroseconds(100);
  // And toggle back
  digitalWrite(oBusNMI, invert_nmi_signal);
}


// ******************************************************************************
// send a single byte to the Bus
// ******************************************************************************
void sendByte(byte b) {

  outByte(b);
  io2 = false;
  triggerNMI();
  // wait for io2 interupt
  unsigned long timeOut = millis() + 300;
  while (io2 == false) {
    delayMicroseconds(2);
    if (millis() > timeOut) {
      io2 = true;
      Serial.println("Timeout in sendByte");
    }
  }
  io2 = false;
}

// ******************************************************************************
// Deserialize the json encoded messages
// ******************************************************************************
void Deserialize() {
  DynamicJsonDocument doc(512);                                  // next we want to analyse the json data
  DeserializationError error = deserializeJson(doc, msgbuffer);  // deserialize the json document

  if (!error) {
    unsigned long newMessageId = doc["rowid"];
    // if we get a new message id back from the database, that means we have a new message
    // if the database returns the same message id, there is no new message for us..
    bool newid = false;
    String channel = doc["channel"];
    if ((channel == "private") and (newMessageId != messageIds[1])) {
      newid = true;
      tempMessageIds[1] = newMessageId;
      String nickname = doc["nickname"];
    }

    if ((channel == "public") and (newMessageId != messageIds[0])) {
      newid = true;
      tempMessageIds[0] = newMessageId;
    }
    if (newid) {
      String message = doc["message"];
      String decoded_message = ' ' + my_base64_decode(message);
      int lines = doc["lines"];
      int msize = decoded_message.length() + 1;
      decoded_message.toCharArray(msgbuffer, msize);
      int outputLength = decoded_message.length();
      msgbuffersize = (int)outputLength;
      msgbuffer[0] = lines;
      msgbuffersize += 1;

      pmCount = doc["pm"];
      haveMessage = 1;
      if (msgtype == "private") haveMessage = 2;

    } else {

      pmCount = doc["pm"];

      // we got the same message id back, so no new messages:
      msgbuffersize = 0;
      haveMessage = 0;
    }
    doc.clear();
  }
}

// ******************************************************************************
// Send out urgent message if available (error messages)
// ******************************************************************************
void doUrgentMessage() {
  int color = 2; // default color for urgent messages is RED
  if (urgentMessage.startsWith("[blk]")) {urgentMessage=urgentMessage.substring(5); color = 7;} // black defaults to white
  if (urgentMessage.startsWith("[blu]")) {urgentMessage=urgentMessage.substring(5); color = 1;}
  if (urgentMessage.startsWith("[red]")) {urgentMessage=urgentMessage.substring(5); color = 2;}
  if (urgentMessage.startsWith("[mag]")) {urgentMessage=urgentMessage.substring(5); color = 3;}
  if (urgentMessage.startsWith("[grn]")) {urgentMessage=urgentMessage.substring(5); color = 4;}
  if (urgentMessage.startsWith("[cya]")) {urgentMessage=urgentMessage.substring(5); color = 5;}
  if (urgentMessage.startsWith("[yel]")) {urgentMessage=urgentMessage.substring(5); color = 6;}
  if (urgentMessage.startsWith("[whi]")) {urgentMessage=urgentMessage.substring(5); color = 7;}
  

  if (urgentMessage != "") {
    urgentMessage = "          " + urgentMessage + "  ";
    outbuffersize = urgentMessage.length() + 1;
    urgentMessage.toCharArray(outbuffer, outbuffersize);
    outbuffer[0] = 1;                   // One line
    outbuffer[1] = 22;                  // AT
    outbuffer[2] = 19;                  // line
    outbuffer[3] = 0;                   // column
    outbuffer[4] = 17;                  // PAPER
    outbuffer[5] = 0;                   // black paper
    outbuffer[6] = 20;                  // INVERSE
    outbuffer[7] = 1;                   // inverse ON
    outbuffer[8] = 16;                  // INK
    outbuffer[9] = color;               // red or green or whatever
    outbuffer[outbuffersize - 3] = 20;  // Inverse
    outbuffer[outbuffersize - 2] = 0;   // inverse off
    send_out_buffer_to_Bus();
    urgentMessage = "";
  }
}

void loadPrgfile() {
  int delayTime = 50;
  delay(2000);  // give the computer some time to boot
  Serial.println("Waiting for start signal");
  int i = 0;
  while (ch != 100) {  // wait for the computer to send byte 100
    delay(10);
    if (i++ > 200) ESP.restart();
  }

  delay(10);
  Serial.println("------ LOAD PRG FILE ------");
  sendByte(5);  // first send the border color

  delayMicroseconds(delayTime);
  sendByte(lowByte(sizeof(prgfile)));
  delayMicroseconds(delayTime);
  sendByte(highByte(sizeof(prgfile)));

  for (int x = 0; x < sizeof(prgfile); x++) {  // Now send all the rest of the bytes
    delayMicroseconds(delayTime);
    sendByte(prgfile[x]);
  }

  Serial.println("------ PRG FILE DONE ------");
  ch = 0;
  ready_to_receive(false);
  io2 = false;
  dataFromBus = false;
}

void translateZXMessage() {
  // do some translations for zx spectrum
  // first byte is number of lines, this determines the start position
  int sp = 20 - msgbuffer[0];
  int b = 0;
  int y = 0;
  int zxColors[] = { 7, 7, 2, 5, 3, 4, 1, 6, 2, 2, 2, 7, 7, 4, 1, 7 };

  // start with number of lines
  outbuffer[0] = msgbuffer[0];
  // then the start position (AT)
  outbuffer[1] = 22;  // AT
  outbuffer[2] = sp;  // line
  outbuffer[3] = 0;   // column
  outbuffer[4] = 17;  // PAPER
  outbuffer[5] = 0;   // black paper
  y = 6;

  // now check the rest of the bytes for color attributes
  for (int x = 1; x < msgbuffersize; x++) {
    b = msgbuffer[x];
    if (b == 143) {  // 143 means inverted text
      outbuffer[y] = 20;
      y++;
      outbuffer[y] = 1;
    } else if (b >= 144 and b < 160) {
      // colors should be translated also

      // 144 = black
      // 145 = white
      // 146 = red
      // 147 = cyan
      // 148 = purple
      // 149 = green
      // 150 = blue
      // 151 = yellow
      // 152 = oranje
      // 153 = brown
      // 154 = pink
      // 155 = gray 1
      // 156 = gray 2
      // 157 = light green
      // 158 = light blue
      // 159 = gray 3

      b = b - 144;
      b = zxColors[b];
      outbuffer[y] = 16;
      y++;
      outbuffer[y] = b;
    } else {
      outbuffer[y] = b;
    }
    y++;
  }

  // copy the buffer size also
  outbuffersize = y;
}

int translateColor(int color) {
  switch (color) {
    case 145:
      return 150;
      break;
    case 146:
      return 146;
      break;
    case 147:
      return 148;
      break;
    case 148:
      return 149;
      break;
    case 149:
      return 147;
      break;
    case 150:
      return 151;
      break;
    case 151:
      return 145;
      break;
    default:
      return color;
  }
}

void ready_to_receive(bool b) {
  if (b)
    outByte(128);
  else
    outByte(0);
  return;
}


uint8_t myShiftIn(uint8_t dataPin, uint8_t clockPin, uint8_t bitOrder) {
  uint8_t value = 0;
  uint8_t i;

  for (i = 0; i < 8; ++i) {
    digitalWrite(clockPin, HIGH);
    delayMicroseconds(5);
    //if (bitOrder == LSBFIRST)
    //    value |= digitalRead(dataPin) << i;
    //else
    value |= digitalRead(dataPin) << (7 - i);
    digitalWrite(clockPin, LOW);
  }
  return value;
}


void myShiftOut(uint8_t dataPin, uint8_t clockPin, uint8_t bitOrder, uint8_t val) {
  uint8_t i;

  digitalWrite(clockPin, LOW);

  for (i = 0; i < 8; i++) {
    if (bitOrder == LSBFIRST) {
      digitalWrite(dataPin, val & 1);
      val >>= 1;
    } else {
      digitalWrite(dataPin, (val & 128) != 0);
      val <<= 1;
    }

    delayMicroseconds(10);
    digitalWrite(clockPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(clockPin, LOW);
  }
}