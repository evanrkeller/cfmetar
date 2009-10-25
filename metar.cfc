<cfcomponent displayname="metar" hint="decode NOAA METAR files into a structure">

<!--- ColdFusion METAR Parser

Author:		Evan Keller <ekeller@evankeller.com>
Version:	2.0 (beta)
Web Site:	http://www.evankeller.com/professional/coldfusion/cf_metar/
Copyright:	2003-2009, by Evan R. Keller. All rights reserved.

About:		METAR is a standardized format for hourly weather observations
			uses by NOAA for aviation weather. This component will parse
			a METAR report and return the data in a human-readable structure.

Version History:
			Version 2.0 (beta) - 10/24/2009
				* Converted to CFC from CF_METAR custom tag
				* Fix problem adding units for wind direction
			Version 1.1 - 3/16/2004
				* Added support for negative temperature and dewpoint
				* Added support for temperature only (no reported dewpoint)
			Version 1.0 - 8/18/2003
				* First release
	
Desired Improvements:
			* Parse remarks

--->

	<cffunction access="remote" name="decode" output="no" returntype="struct">
		<cfargument name="metar" type="string" required="yes" displayname="Metar Text" hint="text of the METAR report">
		<cfargument name="units" type="boolean" required="yes" default=FALSE displayname="Unit" hint="If true, returns data with units of measurement appended.">
		<cfargument name="temp" type="string" required="yes" default="C" displayname="Temperature Format" hint="[C or F] If F, converts temperatures to fahrenheit, else left as Celcius.">
		
		<!--- Input Validation --->
		<cfif NOT REFindNoCase("^(C|F)$", arguments.temp)>
			<cfthrow message="The TEMP parameter to the decode function is not valid" detail="The value for the temperature format argment must be &quot;C&quot; or &quot;F&quot;" type="validation">
		</cfif>
		<!---<cfif NOT REFindNoCase("(METAR|SPECI)/s[A-Z]{4}/s[0-9]{6}Z">
			<cfthrow message="Does not appear to be a valid METAR file" type="Input Validation">
		</cfif>--->
		
		<cfscript>
		
			/*
			METAR or SPECI_CCCC_YYHHMMZ_AUTO or COR_dddff(f)Gff(f)KT_dddVddd_
			VVVVVVSM[_RDD/VVVVFT or RDD/VVVVVVVVVFT]_ww[_NNNhhh or VVhhh
			or SKC/CLR]_TT/TT_APPPP_RMK_(Automated, Manual, Plain Language)_
			(Additive Data and Automated Maintenance Indicators)
			
			1  Type of Report - METAR or SPECI
			2  Station Identifier - CCCC
			3  Date and Time of Report - YYHHMMZ
			4  Report Modifier - AUTO or COR
			5  Wind - dddff(f)Gff(f)KT_dddVddd
			6  Visibility - VVVVVVSM
			7  Runway Visibility Range = RDD/VVVVFT or RDD/VVVVVVVVVFT
			8  Present Weather - ww
			9  Sky Conditions - NNNhhh or VVhhh or SKC/CLR
			10 Temperature and Dew Point - TT/TT
			11 Altimeter - APPPP
			*/
			
			arguments.metar = replace(arguments.metar, chr(13), "", "ALL");
			arguments.metar = replace(arguments.metar, chr(10), " ", "ALL");
			
			decoded = structnew();
			
			metararray = listtoarray(arguments.metar, " ");
			
			pos = "1";
			maxpos = "#arraylen(metararray)#";
			
			// Report Date (ex: 2003/12/31)
			if (REFindNoCase("[0-9]{4}\/[0-9]{2}\/[0-9]{2}", metararray[pos])) {
				decoded.date = metararray[pos];
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Report Time (ex: 23:59)
			if (REFindNoCase("[0-9]{2}\:[0-9]{2}", metararray[pos])) {
				decoded.time = metararray[pos];
				if (arguments.units) {decoded.time = decoded.time & " Z";}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Typeof Report (ex: arguments.metar)
			if (REFindNoCase("(METAR|SPECI)", metararray[pos])) {
				if (metararray[pos] is "METAR") {
					decoded.type = "Routine Weather Report";
				} else if (metararray[pos] is "SPECI") {
					decoded.type = "Special Weather Report"	;
				}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Station Identidier (ex: KLAX)
			if (REFindNoCase("[A-Z]{4}", metararray[pos])) {
				decoded.station = metararray[pos];
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Report Day and Time (ex: 271453Z)
			if (REFindNoCase("[0-9]{6}Z", metararray[pos])) {
				decoded.day = left(metararray[pos], 2);
				decoded.time = mid(metararray[pos], 3, 2) & ":" & mid(metararray[pos], 5, 2);
				if (arguments.units) {decoded.time = decoded.time & " Z";}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Report Modifier (ex: AUTO)
			if (REFindNoCase("(AUTO|COR)", metararray[pos])) {
				if (metararray[pos] is "AUTO") {
					decoded.modifier = "Automated";
				} else if (metararray[pos] is "COR") {
					decoded.modifier = "Correction"	;
				}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Calm Wind (ex: 00000KT)
			if (REFindNoCase("00000KT", metararray[pos])) {
				decoded.windDirection = "Calm";
				decoded.windSpeed = "Calm";
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Basic Wind Speed and Direction (ex: 04012KT)
			if (REFindNoCase("[0-9]{5,6}KT", metararray[pos])) {
				decoded.windDirection = left(metararray[pos], 3);
				decoded.windSpeed = mid(metararray[pos], 4, len(metararray[pos]) - 5);
				if (arguments.units) {
					decoded.windDirection = decoded.windDirection & "&deg;";
					decoded.windSpeed = decoded.windSpeed & " Knots per hour";
				}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Wind Speed with Gust and Direction (ex: 04012G22KT)
			if (REFindNoCase("[0-9]{5,6}G[0-9]{2,3}KT", metararray[pos])) {
				decoded.windDirection = left(metararray[pos], 3);
				decoded.windSpeed = mid(metararray[pos], 4, find("G", metararray[pos]) - 4);
				decoded.windGust = mid(metararray[pos], find("G", metararray[pos]) + 1, find("KT", metararray[pos]) - find("G", metararray[pos]) - 1);
				if (arguments.units) {
					decoded.windDirection = decoded.windDirection & "&deg;";
					decoded.windSpeed = decoded.windSpeed & " Knots per hour";
					decoded.windGust = decoded.windGust & " Knots per hour";
				}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Variable wind direction under 6 knots (ex: VRB04KT)
			if (REFindNoCase("VRB0[0-6]KT", metararray[pos])) {
				decoded.windDirection = "Variable";
				decoded.windSpeed = mid(metararray[pos], 4, 2);
				if (arguments.units) {
					decoded.windSpeed = decoded.windSpeed & " Knots per hour";
				}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Variable wind direction (ex: 180V210)
			if (REFindNoCase("[0-9]{3}V[0-9]{3}", metararray[pos])) {
				decoded.windDirectionVarA = Left(metararray[pos], 3);
				decoded.windDirectionVarB = Right(metararray[pos], 3);
				if (arguments.units) {
					decoded.windDirectionVarA = decoded.windDirection & "&deg;";
					decoded.windDirectionVarB = decoded.windSpeed & "&deg;";
				}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Visibility with a whole number and a fraction (ex: 1 1/2SM)
			if (REFindNoCase("[12]", metararray[pos]) AND REFindNoCase("[0-9]{1}\/[0-9]{1,2}SM", metararray[pos+1])) {
				decoded.visibility = metararray[pos] & " " & Left(metararray[pos+1], Len(metararray[pos+1])-2);
				if (arguments.units) {decoded.visibility = decoded.visibility & " miles";}
				if (pos is not maxpos) {
					pos = pos + 2;
				}
			}
			
			// Visibility as a fraction (ex: 3/4SM)
			if (REFindNoCase("[M]?[0-9]{1}\/[0-9]{1,2}SM", metararray[pos])) {
				if (Left(metararray[pos], 1) IS "M") {
					decoded.visibilitry = "less than " & Mid(metararray[pos], 2, Len(metararray[pos])-3);
				} else {
					decoded.visibilitry = Left(metararray[pos], Len(metararray[pos])-2);
				}
				if (arguments.units) {decoded.visibility = decoded.visibility & " miles";}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Visibility (ex: 10SM)
			if (REFindNoCase("[0-9]{1,3}SM", metararray[pos])) {
				decoded.visibility = Left(metararray[pos], Len(metararray[pos])-2);
				if (arguments.units) {decoded.visibility = decoded.visibility & " miles";}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Runway Visibility (ex: R01L/0800V1200FT)
			while (REFindNoCase("R[0-9]{2}[LCR]?\/[MP]?[0-9]{2}00[V]?[MP]?[0-9]{0,4}FT", metararray[pos])) {
				if (not isDefined("decoded.RVR")) {
					decoded.RVR = arrayNew(1);
				}
				arrayAppend(decoded.RVR, structNew());
				decoded.RVR[arrayLen(decoded.RVR)].Runway = mid(metararray[pos], 2, find("/", metararray[pos])-2);
				if (mid(metararray[pos], find("/", metararray[pos]) + 1, 1) is "M") {
					decoded.RVR[arrayLen(decoded.RVR)].Visibility = "less than " & mid(metararray[pos], find("/", metararray[pos]) + 2, 4) + 0;
				} else if (mid(metararray[pos], find("/", metararray[pos]) + 1, 1) is "P") {
					decoded.RVR[arrayLen(decoded.RVR)].Visibility = "more than " & mid(metararray[pos], find("/", metararray[pos]) + 2, 4) + 0;
				} else {
					decoded.RVR[arrayLen(decoded.RVR)].Visibility = mid(metararray[pos], find("/", metararray[pos]) + 1, 4) + 0;
				}
				//if (arguments.units) {decoded.RVR[arrayLen(decoded.RVR)].Visibility = decoded.RVR[arrayLen(decoded.RVR)].Visibility & " feet";}
				if (find("V", metararray[pos])) {
					if (mid(metararray[pos], find("V", metararray[pos]) + 1, 1) is "P") {
						decoded.RVR[arrayLen(decoded.RVR)].MaxVisibility = "more than " & mid(metararray[pos], find("V", metararray[pos]) + 2, 4) + 0;
					} else {
						decoded.RVR[arrayLen(decoded.RVR)].MaxVisibility = mid(metararray[pos], find("V", metararray[pos]) + 1, 4) + 0;
					}
					if (arguments.units) {decoded.RVR[arrayLen(decoded.RVR)].MaxVisibility = decoded.RVR[arrayLen(decoded.RVR)].MaxVisibility & " feet";}
				}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			//Present Weather (ex: +SHRA)
			while (REFindNoCase("[(-|\+|VC)]?[(MI|PR|BC|DR|BL|SH|TS|FZ)]?(DZ|RA|SN|SG|IC|PL|GR|GS|UP|BR|FG|FU|VA|DU|SA|HZ|PY|PO|SQ|FC|SS|DS)", metararray[pos])) {
				if (not isDefined("decoded.weather")) {
					decoded.weather = arrayNew(1);
				}
				arrayAppend(decoded.weather, "");
				if (Not REFind("(-|\+|VC)", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= "Moderate ";}
				if (Find("-", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= "Light ";}
				if (Find("+", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= "Heavy ";}
				if (Find("MI", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)]& "Shallow ";}
				if (Find("PR", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Partial ";}
				if (Find("BC", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Patches of ";}
				if (Find("DR", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Low Drifting ";}
				if (Find("FZ", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Freezing ";}
				if (Find("DZ", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Drizzle";}
				if (Find("RA", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Rain";}
				if (Find("SN", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Snow";}
				if (Find("SG", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Snow Grains";}
				if (Find("IC", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Ice Crystals";}
				if (Find("PL", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Ice Pellets";}
				if (Find("GR", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Hail";}
				if (Find("GS", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Small Hail and/or Snow Pellets";}
				if (Find("UP", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Unknown Precipitation";}
				if (Find("BR", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Mist";}
				if (Find("FG", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Fog";}
				if (Find("FU", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Smoke";}
				if (Find("VA", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Volcanic Ash";}
				if (Find("DU", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Widespread Dust";}
				if (Find("SA", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Sand";}
				if (Find("HZ", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Haze";}
				if (Find("PY", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Spray";}
				if (Find("PO", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Well-Developed Dust/Sand Whirls";}
				if (Find("SQ", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Squalls";}
				if (Find("FC", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Funnel Cloud, Tornado or Water Spout";}
				if (Find("SS", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Sand Storm";}
				if (Find("DS", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & "Dust Storm";}
				if (Find("SH", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & " Showers";}
				if (Find("TS", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & " Thunderstorm";}
				if (Find("VC", metararray[pos])) {decoded.weather[arrayLen(decoded.weather)]= decoded.weather[arrayLen(decoded.weather)] & " In the Vicinity";}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			//Sky Conditions (ex: BKN060)
			while (REFindNoCase("(VV|SKC|CLR|FEW|SCT|BKN|OVC)[0-9]{0,3}", metararray[pos])) {
				if (not isDefined("decoded.skycondition")) {
					decoded.skycondition = arrayNew(1);	
				}
				arrayAppend(decoded.skycondition, structNew());
				if (REFindNoCase("(VV|FEW|SCT|BKN|OVC)[0-9]{0,3}", metararray[pos])) {
					decoded.skycondition[arrayLen(decoded.skycondition)].height = Right(metararray[pos], 3) & "00";
					decoded.skycondition[arrayLen(decoded.skycondition)].height = decoded.skycondition[arrayLen(decoded.skycondition)].height + 0;
					if (arguments.units) {decoded.skycondition[arrayLen(decoded.skycondition)].height = decoded.skycondition[arrayLen(decoded.skycondition)].height & " feet";}
				}
				if (Find("VV", metararray[pos])) {decoded.skycondition[arrayLen(decoded.skycondition)].skycover = "Vertical Visibility";}
				if (Find("FEW", metararray[pos])) {decoded.skycondition[arrayLen(decoded.skycondition)].skycover = "Few";}
				if (Find("SCT", metararray[pos])) {decoded.skycondition[arrayLen(decoded.skycondition)].skycover = "Scattered";}
				if (Find("BKN", metararray[pos])) {decoded.skycondition[arrayLen(decoded.skycondition)].skycover = "Broken";}
				if (Find("OVC", metararray[pos])) {decoded.skycondition[arrayLen(decoded.skycondition)].skycover = "Overcast";}
				if (REFind("(SKC|CLR)", metararray[pos])) {decoded.skycondition[arrayLen(decoded.skycondition)].skycover = "Clear";}
				//Process Sky Condition later
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Temperature and Dew Point (ex: 14/M01)
			if (REFindNoCase("[M]?[0-9]{2}\/[M]?[0-9]{2}", metararray[pos])) {
				if (left(metararray[pos], 1) is "M") {
					decoded.temperature = evaluate("-#mid(metararray[pos], 2, 2)#");
				} else {
					decoded.temperature = left(metararray[pos], 2);
				}
				if (mid(metararray[pos], find("/", metararray[pos]) + 1, 1) eq "M") {
					decoded.dewpoint = evaluate("-#right(metararray[pos], 2)#");
				} else {
					decoded.dewpoint = right(metararray[pos], 2);
				}
				if (arguments.units) {
					if (arguments.temp IS "F") {
						decoded.temperature = decoded.temperature * 1.8 + 32 & "&deg; F";
						decoded.dewpoint = decoded.dewpoint * 1.8 + 32 & "&deg; F";
					} else {
						decoded.temperature = decoded.temperature & "&deg; C";
						decoded.dewpoint = decoded.dewpoint & "&deg; C";
					}
				} else {
					if (arguments.temp IS "F") {
						decoded.temperature = decoded.temperature * 1.8 + 32;
						decoded.dewpoint = decoded.dewpoint * 1.8 + 32;
					}
				}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Temperature Only (ex: M02/)
			if (REFindNoCase("[M]?[0-9]{2}\/", metararray[pos])) {
				if (left(metararray[pos], 1) is "M") {
					decoded.temperature = evaluate("-#mid(metararray[pos], 2, 2)#");
				} else {
					decoded.temperature = left(metararray[pos], 2);
				}
				if (arguments.units) {
					if (arguments.temp IS "F") {
						decoded.temperature = decoded.temperature * 1.8 + 32 & "&deg; F";
					} else {
						decoded.temperature = decoded.temperature & "&deg; C";
					}
				} else {
					if (arguments.temp IS "F") {
						decoded.temperature = decoded.temperature * 1.8 + 32;
					}
				}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}
			
			// Air Pressure (ex: A2992)
			if (REFindNoCase("A[0-9]{4}", metararray[pos])) {
				decoded.airpressure = mid(metararray[pos], 2, 2) & "." & right(metararray[pos], 2);
				if (arguments.units) {decoded.airpressure = decoded.airpressure & " inches of hg";}
				if (pos is not maxpos) {
					pos = pos + 1;
				}
			}

		
		</cfscript>
		
		<cfreturn decoded />
	</cffunction>
	
	<cffunction access="public" name="getObservation" output="no" returntype="string">
		<cfargument name="station" type="string" required="yes" displayname="Metar Text" hint="text of the METAR report">
		<cftry>
			<cfhttp url="http://weather.noaa.gov/pub/data/observations/metar/stations/#arguments.station#.TXT" method="get" resolveurl="no">
			</cfhttp>
			<cfcatch>
				<cfset cfhttp.FileContent = "">
			</cfcatch>
		</cftry>

		<cfreturn cfhttp.FileContent />
	
	</cffunction>
	
</cfcomponent>