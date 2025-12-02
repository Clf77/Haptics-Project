//--------------------------------------------------------------------------
// Code to test basic Hapkit functionality (sensing and force output)
// Contributors to code: Allison Okamura, Tania Morimoto, Melisa Orta Martinez
// Updated by Cara Nunez 9.19.2024
//--------------------------------------------------------------------------
// Parameters that define what environment to render
#define ENABLE_VIRTUAL_WALL
//#define ENABLE_LINEAR_DAMPING
//#define ENABLE_NONLINEAR_FRICTION
//#define ENABLE_HARD_SURFACE
//#define ENABLE_BUMP_VALLEY
//#define ENABLE_TEXTURE

// Includes
#include <math.h>

// Pin declares
int pwmPin = 5; // PWM output pin for motor 1
int dirPin = 8; // direction output pin for motor 1
int sensorPosPin = A2; // input pin for MR sensor
int fsrPin = A3; // input pin for FSR sensor

// Position tracking variables
int updatedPos = 0;     // keeps track of the latest updated value of the MR sensor reading
int rawPos = 0;         // current raw reading from MR sensor
int lastRawPos = 0;     // last raw reading from MR sensor
int lastLastRawPos = 0; // last last raw reading from MR sensor
int flipNumber = 0;     // keeps track of the number of flips over the 180deg mark
int tempOffset = 0;
int rawDiff = 0;
int lastRawDiff = 0;
int rawOffset = 0;
int lastRawOffset = 0;
const int flipThresh = 700;  // threshold to determine whether or not a flip over the 180 degree mark occurred
boolean flipped = false;

// Kinematics variables
double xh = 0;           // position of the handle [m]
double theta_s = 0;      // Angle of the sector pulley in deg
double xh_prev;          // Distance of the handle at previous time step
double xh_prev2;
double dxh;              // Velocity of the handle
double dxh_prev;
double dxh_prev2;
double dxh_filt;         // Filtered velocity of the handle
double dxh_filt_prev;
double dxh_filt_prev2;

// Force output variables
double force = 0;           // force at the handle
double Tp = 0;              // torque of the motor pulley
double duty = 0;            // duty cylce (between 0 and 255)
unsigned int output = 0;    // output command to the motor


// --------------------------------------------------------------
// Setup function -- NO NEED TO EDIT
// --------------------------------------------------------------
void setup() 
{
  // Set up serial communication
  Serial.begin(9600);
  
  // Set PWM frequency 
  setPwmFrequency(pwmPin,1); 
  
  // Input pins
  pinMode(sensorPosPin, INPUT); // set MR sensor pin to be an input
  pinMode(fsrPin, INPUT);       // set FSR sensor pin to be an input

  // Output pins
  pinMode(pwmPin, OUTPUT);  // PWM pin for motor A
  pinMode(dirPin, OUTPUT);  // dir pin for motor A
  
  // Initialize motor 
  analogWrite(pwmPin, 0);     // set to not be spinning (0/255)
  digitalWrite(dirPin, LOW);  // set direction
  
  // Initialize position valiables
  lastLastRawPos = analogRead(sensorPosPin);
  lastRawPos = analogRead(sensorPosPin);
}


// --------------------------------------------------------------
// Main Loop
// --------------------------------------------------------------
void loop()
{
  
  //*************************************************************
  //*** Section 1. Compute position in counts (do not change) ***  
  //*************************************************************

  // Get voltage output by MR sensor
  rawPos = analogRead(sensorPosPin);  //current raw position from MR sensor

  // Calculate differences between subsequent MR sensor readings
  rawDiff = rawPos - lastRawPos;          //difference btwn current raw position and last raw position
  lastRawDiff = rawPos - lastLastRawPos;  //difference btwn current raw position and last last raw position
  rawOffset = abs(rawDiff);
  lastRawOffset = abs(lastRawDiff);
  
  // Update position record-keeping vairables
  lastLastRawPos = lastRawPos;
  lastRawPos = rawPos;
  
  // Keep track of flips over 180 degrees
  if((lastRawOffset > flipThresh) && (!flipped)) { // enter this anytime the last offset is greater than the flip threshold AND it has not just flipped
    if(lastRawDiff > 0) {        // check to see which direction the drive wheel was turning
      flipNumber--;              // cw rotation 
    } else {                     // if(rawDiff < 0)
      flipNumber++;              // ccw rotation
    }
    if(rawOffset > flipThresh) { // check to see if the data was good and the most current offset is above the threshold
      updatedPos = rawPos + flipNumber*rawOffset; // update the pos value to account for flips over 180deg using the most current offset 
      tempOffset = rawOffset;
    } else {                     // in this case there was a blip in the data and we want to use lastactualOffset instead
      updatedPos = rawPos + flipNumber*lastRawOffset;  // update the pos value to account for any flips over 180deg using the LAST offset
      tempOffset = lastRawOffset;
    }
    flipped = true;            // set boolean so that the next time through the loop won't trigger a flip
  } else {                        // anytime no flip has occurred
    updatedPos = rawPos + flipNumber*tempOffset; // need to update pos based on what most recent offset is 
    flipped = false;
  }
 
  //*************************************************************
  //*** Section 2. Compute position in meters *******************
  //*************************************************************

  // ADD YOUR CODE HERE (Use your code from Problems 1 and 2)
  // ADD YOUR CODE HERE (Use ypur code from Problems 1 and 2)
  // Define kinematic parameters you may need
double rh = 0.069;   //[m]
  // Step B.1: print updatedPos via serial monitor
 double ts =updatedPos*0.0125-2.2; // Compute the angle of the sector pulley (ts) in degrees based on updatedPos
  double tsrad=ts*(3.14/180);
  //sin(tsrad)=xh/rh
  xh=sin(tsrad)*rh;
  //Serial.println(xh,5);
  //xhmax=0.04798
  //xhmin=-0.05809
  // Step B.7: xh = ?;       // Compute the position of the handle (in meters) based on ts (in radians)
  // Step B.8: print xh via serial monitor

  // Calculate velocity with loop time estimation
  dxh = (double)(xh - xh_prev) / 0.001;

  // Calculate the filtered velocity of the handle using an infinite impulse response filter
  dxh_filt = .9*dxh + 0.1*dxh_prev; 
    
  // Record the position and velocity
  xh_prev2 = xh_prev;
  xh_prev = xh;
  
  dxh_prev2 = dxh_prev;
  dxh_prev = dxh;
  
  dxh_filt_prev2 = dxh_filt_prev;
  dxh_filt_prev = dxh_filt;
  
  //*************************************************************
  //*** Section 3. Assign a motor output force in Newtons *******  
  //*************************************************************
  //*************************************************************
  //******************* Rendering Algorithms ********************
  //*************************************************************
   
 
  
  //*************************************************************
  //*** Section 3. Assign a motor output force in Newtons *******  
  //*************************************************************
 
  // ADD YOUR CODE HERE
  // Define kinematic parameters you may need
     //double rp = 0.0092;   //[m]
     //double rs = 0.075;   //[m] 
     //double rhandle = 0.089;   //[m] 
  //force = 0; // You can  generate a force by assigning this to a constant number (in Newtons) or use a haptic rendering / virtual environment
// double k=5;
// double force=-k*xh;
// Tp = force*0.01092;    


// Pick which effect is active
#define EFFECT_VIRTUAL_WALL  (1)
#define EFFECT_SPRING        (2)
#define EFFECT_DAMPER        (3)
#define EFFECT_KARNOPP       (4)
#define EFFECT_HARD_SURFACE  (5)
#define EFFECT_BUMPNVALLEY   (6)
#define EFFECT_TEXTURED      (7)


//ACTIVE_EFFECT=EFFECT_VIRTUAL_WALL

#define ACTIVE_EFFECT EFFECT_VIRTUAL_WALL 

#if ACTIVE_EFFECT==EFFECT_VIRTUAL_WALL
if (xh > 0.005) {
  double k = 200.0;
   force = -k * (xh - 0.005);
  Tp = force * 0.01092;   // motor pulley torque
}
else {
    Tp = 0.0;
  }
#endif

//Serial.println(xh,1);



#if ACTIVE_EFFECT==EFFECT_DAMPER
double cdamping=5.0; //N*s/m
   force=-dxh_filt*cdamping;
  Tp = force * 0.01092;   // motor pulley torque

#endif

#if ACTIVE_EFFECT == EFFECT_KARNOPP


static int   sign_hold = 0;     // -1, 0, +1 (held friction sign near zero)
static int   in_rest   = 1;     // 1 = rest (stick), 0 = slip
static double x_hold   = 0.0;   // rest (anchor) position for the stiff spring

double Fc    = 0.5;             // Coulomb [N]
double B     = 0.2;             // viscous [N*s/m]
double v_on  = 0.1;           // leave-rest threshold [m/s]
double v_off = 0.01;           // enter-rest threshold [m/s]

double F_s   = 20.0;             // static limit [N] (>= Fc)
double k_static = 700.0;        // very stiff spring [N/m] active only at rest

double v = dxh_filt;

//  Update hysteresis sign based on velocity 
if (v >  v_on)  sign_hold = +1;
else if (v < -v_on) sign_hold = -1;
else if (fabs(v) < v_off) sign_hold = 0;


//  State transitions 
if (fabs(v) > v_on) {
  in_rest = 0;  // moving fast enough → slip
} else if (fabs(v) < v_off && in_rest == 0) {
  // just re-entered rest: latch a new anchor
  x_hold = xh_prev;
  in_rest = 1;
}
 //Serial.println(v, 3);

if (in_rest) {
  // Stiff virtual spring around x_hold
  double F_spring = -k_static * (xh - x_hold);

  // Clamp spring to static limit
  if (F_spring >  F_s) F_spring =  F_s;
  if (F_spring < -F_s) F_spring = -F_s;

  // If the spring hits the static limit, we are at breakaway 
  if (fabs(F_spring) >= F_s && fabs(v) >= v_off) {
    in_rest = 0;  // breakaway
   // Serial.println("Breakaway");
  }
  force = F_spring;                 // oppose small forces at rest
  //Serial.println(F_spring, 3);
} else {
  // Slip: viscous + Coulomb opposing motion 
  int s = sign_hold;
  if (s == 0) s = (v > 0) ? 1 : -1;
  force = -(B * v) - Fc * s;
}

Tp = force * 0.01092;
#endif



#if ACTIVE_EFFECT == EFFECT_HARD_SURFACE
 double v = dxh_filt;
 double impact=v*10.0;
 double k = 100.0;
 double spring_force=0;
 int t=0;
 if ((xh > 0.005) && (v>0.005)){
    for (int t=1; t<=10; ++t){
      spring_force = -k * (xh - 0.005);
        force = spring_force + (impact * sin((double)t) * exp(-0.1 * (double)t));
        Tp = force * 0.01092;   // motor pulley torque
    } 
  }
else if  (xh > 0.005) {
   spring_force = -k * (xh - 0.005);
  Tp = spring_force * 0.01092;   // motor pulley torque
}

else {
    Tp = 0.0;
  }
#endif



#if ACTIVE_EFFECT == EFFECT_BUMPNVALLEY
 int t=0;
 double hill_xs=0.02;
double hill_xe=0.04;
double valley_xs=-0.02;
  double valley_xe=-0.03;

 if (xh > hill_xs && xh<hill_xe) 
 {
        force =  3*sin((xh - hill_xs)*3.1415/(hill_xe-hill_xs));
        //  Serial.println(force,5);

        Tp = force * 0.01092;   // motor pulley torque
    } 
  
else if (xh < valley_xs && xh>valley_xe) 
{
       force =  3*sin(((xh - valley_xs)*3.1415)/(valley_xs-valley_xe));
       Tp = force * 0.01092;   // motor pulley torque
      // Serial.println(force,5);
   } 
  
else {
    Tp = 0.0;
  }
#endif



#if ACTIVE_EFFECT ==EFFECT_TEXTURED
 double v = dxh_filt;
 double impact=v*10.0;
 int t=0;
 if (v>0.005){
    for (int t=1; t<=10; ++t){
        force = (impact * sin((double)t) * exp(-0.1 * (double)t));
        Tp = force * 0.01092;   // motor pulley torque
    } 
  }

else {
    Tp = 0.0;
  }
#endif


  //*************************************************************
  //*** Section 4. Force output (do not change) *****************
  //*************************************************************
  
  // Determine correct direction for motor torque
  if(force > 0) { 
    digitalWrite(dirPin, HIGH);
  } else {
    digitalWrite(dirPin, LOW);
  }

  // Compute the duty cycle required to generate Tp (torque at the motor pulley)
  duty = sqrt(abs(Tp)/0.03);

  // Make sure the duty cycle is between 0 and 100%
  if (duty > 1) {            
    duty = 1;
  } else if (duty < 0) { 
    duty = 0;
  }  
  output = (int)(duty* 255);   // convert duty cycle to output signal
  analogWrite(pwmPin,output);  // output the signal
}

// --------------------------------------------------------------
// Function to set PWM Freq -- DO NOT EDIT
// --------------------------------------------------------------
void setPwmFrequency(int pin, int divisor) {
  byte mode;
  if(pin == 5 || pin == 6 || pin == 9 || pin == 10) {
    switch(divisor) {
      case 1: mode = 0x01; break;
      case 8: mode = 0x02; break;
      case 64: mode = 0x03; break;
      case 256: mode = 0x04; break;
      case 1024: mode = 0x05; break;
      default: return;
    }
    if(pin == 5 || pin == 6) {
      TCCR0B = TCCR0B & 0b11111000 | mode;
    } else {
      TCCR1B = TCCR1B & 0b11111000 | mode;
    }
  } else if(pin == 3 || pin == 11) {
    switch(divisor) {
      case 1: mode = 0x01; break;
      case 8: mode = 0x02; break;
      case 32: mode = 0x03; break;
      case 64: mode = 0x04; break;
      case 128: mode = 0x05; break;
      case 256: mode = 0x06; break;
      case 1024: mode = 0x7; break;
      default: return;
    }
    TCCR2B = TCCR2B & 0b11111000 | mode;
  }
}

