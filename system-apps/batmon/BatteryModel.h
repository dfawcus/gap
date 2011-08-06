/*
   Project: batmon

   Copyright (C) 2006-2011 GNUstep Application Project

   Author: Riccardo Mottola

   Created: 2006-01-14 23:58:48 +0100 by Riccardo

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/


@class NSString;

@interface BatteryModel : NSObject
{
#if defined (linux)
    @private char     batteryStatePath0[1024];
    @private char     batteryInfoPath0[1024];
    @private char     apmPath[1024];
    @private NSString *batterySysAcpiString;

    @private BOOL     useACPIsys;
    @private BOOL     useACPIproc;
    @private BOOL     useAPM;
    @private BOOL     usePMU;
#endif

    @private BOOL     useWattHours;
    @private float    volts;
    @private float    amps;
    @private float    watts;
    @private float    desCap;
    @private float    lastCap;
    @private float    currCap;
    @private float    warnCap;
    @private float    chargePercent;
    @private float    timeRemaining;
    @private BOOL     isCharging;
  
    @private NSString *chargeState;
    @private NSString *batteryType;
    @private NSString *batteryManufacturer;

}

- (void)update;
- (float)volts;
- (float)amps;
- (float)watts;
- (float)timeRemaining;
- (float)remainingCapacity;
- (float)warningCapacity;
- (float)lastCapacity;
- (float)designCapacity;
- (float)chargePercent;

- (BOOL)isCritical;
- (BOOL)isCharging;

- (BOOL)isUsingWattHours;

- (NSString *)state;
- (NSString *)batteryType;
- (NSString *)manufacturer;

@end


