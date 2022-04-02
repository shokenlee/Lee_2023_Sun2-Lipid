// For quantifying nuclear rim vs intra-nucleus ratio of the given signal
// Primarily for NLS-DAG sensor

print("\\Clear");

// ----- Parameters -----
// Formats
file_format = "nd2";
save_format = "tif";

// 1. Background value based on manual measurement
background = 112;

// 2. Gaussian blur sigma
gaussian_sigma = 1;

// 3. Autothreshold method
method = "Li"
min_area_of_roi = 50;
max_area_of_roi = 500;

// 4. How many times of erosion to be done to make a mask for nuclear area inside the rim
erosion_repeats = 3;

// 5. Measurement items in "Set measurement"
measured_values = "area mean min centroid";

// Get the directory
dataFolder = getDirectory("Choose the folder you want to process");


// ---- Measurement ---
// Make a file list and repeat the analysis for all images in the directory
filelist = getFileList(dataFolder);
for (i = 0; i < lengthOf(filelist); i++) {
    file = filelist[i];
    if (endsWith(file, file_format)) { 
        doAnalysis(file);
        print('Done: ' + file);
        run("Close All");
    } 
}

// --- Functions ---
// --- Primary functions ---

function doAnalysis(file) { 
	// Open a file and perform analysis for all nuclei
	open(file);
	
	// Count and define how many nuclei you have to analyze
	waitForUser("Count how many nuclei you have to analyze");
	n_of_nuclei = getNumber("How many nuclei do you want to analyze?", 0);
	
	// Make arrays to which values are stored
	Areas = newArray(n_of_nuclei);
	Means_whole = newArray(n_of_nuclei);
	Means_inside = newArray(n_of_nuclei);
	Means_periphery = newArray(n_of_nuclei);
	Ratios = newArray(n_of_nuclei);
	
	for (i = 1; i <= n_of_nuclei; i++) {
		// Show counter
		print(i + "out of " + n_of_nuclei + " nuclei being in analysis...");

		// Clean up results and ROI manager
		Clear_Results_ROImanager();
		
		// Define cropping area manually and duplicate the image of the area
		waitForUser("Crop the area of interest");
		run("Duplicate...", "title=Cropped"); // this is the image on which measurement is based
		
		// Autothreshold to make a binary image
		run("Duplicate...", "title=Binary"); // this is going to be a binary image for ROI and mask generation
		run("Gaussian Blur...", "sigma=" + gaussian_sigma);
		setOption("BlackBackground", true);
		run("Auto Threshold", "method=" + method + " white");
		
		
		// Analyze particle, ROIs defined - Skip
		selectWindow("Binary");
		run("Set Measurements...", "area mean min centroid redirect=" + "Cropped" +" decimal=3");
		run("Analyze Particles...", "size=" + min_area_of_roi + "-" + max_area_of_roi + "exclude include add");

		// Judges if a ROI wrapping the nucleus was created
		// If not, just save the cropped image and go to next
		if (roiManager("count") != 0) {
			// Display ROIs on original image and save it
			selectWindow("Cropped");
			roiManager("Show None");
			roiManager("Show All with labels");
			run("Flatten");
			saveAs(save_format, dataFolder + file + "_" + i);
			
			//// Instead, draw a circle
			//waitForUser("Draw a circle");
			//roiManager("Add");
			//roiManager("Show All with labels");
			
			// Make a mask for extracting internal nuclei
			roi_of_interest = getNumber("Give the ROI number", 0);
			roiManager("select", roi_of_interest-1);
			run("Create Mask");
			selectWindow("Mask");
			for (j = 0; j < erosion_repeats; j++) {
				run("Erode");
			}
			run("Divide...", "value=255");
			run("16-bit");
			
			// Measure within ROI
			measure_in_ROI("Cropped", measured_values);
//			run("Set Measurements...", "area mean min centroid redirect=Cropped decimal=3");
//			roiManager("deselect");
//			roiManager("measure");
			
			// Store the values to the array T1, A1, M1
			A1 = getResult("Area", roi_of_interest-1);
			M1 = getResult("Mean", roi_of_interest-1);
			T1 = A1* M1;
			
			// Measure total intensity of binary images within ROIs, which is equal to the intra-nuclear area A2
			run("Clear Results");
			run("Set Measurements...", "area mean min centroid redirect=Mask decimal=3");
			roiManager("deselect");
			roiManager("measure");
			M_mask = getResult("Mean", roi_of_interest-1);
			A2 = A1 * M_mask;
			
			// Mask the Max-ed C1 by the binary image
			imageCalculator("Multiply create", "Cropped","Mask");
			
			// Measure the masked images within ROIs, giving intra-nuclear intensity T2
			// thus obtain M2 from T2 / A2
			selectWindow("Result of Cropped");
			rename("Masked_cropped");
			run("Set Measurements...", "area mean min centroid redirect=Masked_cropped decimal=3");
			run("Clear Results");
			roiManager("deselect");
			roiManager("measure");
			M2_fake = getResult("Mean", roi_of_interest-1); // this is an underestmated value due to zeros in periphery
			T2 = A1 * M2_fake;
			M2_real = T2 / A2 - background;
			
			// Obtain T3 by T1-T2 and A3 by A1-A2, then M3 = T3 / A3
			T3 = T1 - T2;
			A3 = A1 - A2;
			M3 = T3 / A3 - background;
			
			// Obtain the ratio R = M3 / M2, then output as CSV
			R = M3 / M2_real;
		
		    // Store the values to the arrays
		    Areas[i-1] = A1;
		    Means_whole[i-1] = M1;
		    Means_inside[i-1] = M2_real;
		    Means_periphery[i-1] = M3;
		    Ratios[i-1] = R;
		}

		else {
			selectWindow("Cropped");
			saveAs(save_format, dataFolder + file + "_" + i + "_Failed");
		}
		
	    // Close all images other than the original image
		selectWindow(file);
		close("\\Others");
	}
	
	
	// Store the values to CSV
	run("Clear Results");
	for (i = 0; i < n_of_nuclei; i++) {
	    setResult("FileName", i, file);
	    setResult("Mean_whole", i, Means_whole[i]);
	    setResult("Mean_internal", i, Means_inside[i]);
	    setResult("Mean_periphery", i, Means_periphery[i]);
	    setResult("Ratio", i, Ratios[i]);
	}
	
	selectWindow("Results");
	saveAs("Measurements", dataFolder + "_" + file + "_Results.csv");

}


// --- Secondary functions ---

function Clear_Results_ROImanager() { 
	// Clean up the result table and ROI manager
	run("Clear Results");
	if (roiManager("count") != 0) {
		roiManager("deselect");
		roiManager("delete");
	};
}

function measure_in_ROI(imageName, measured_values) { 
	// Perform
	run("Set Measurements...", measured_values + " redirect=" + imageName +" decimal=3");
	roiManager("deselect");
	roiManager("measure");
}




