Bash script to convert log files generated from the Pilot VAF to MAF converter board from the guys over at http://max.pilotpowersupply.com/ in Kyrgyzstan.
This allows the files to be easily read by MegaLogViewer. 

The file structure is a 15-byte header followed by rows of 15 bytes of data. 
I have not finished mapping out the header, but I have the MAF, O2, and output (to ECM) signals mapped.

Time column is added calculated from the log intervals and is accurate. 
The O2 0-255 ADC value is copied to a new column labled "AFR" with a linear conversion 7.35 = 0 and 22.39 = 255.  
This is correct for the innovate MTX-l wideband I'm running, you may need to update the numbers for your own use. 


The Config file just accepts a directory path.
