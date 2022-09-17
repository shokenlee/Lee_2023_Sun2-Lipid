
// --- This code is for measuring nLD area along with a protein intensity in nucleus
// nucleus (C1), BODIPY(C2) and target (C3) intensity within nuclear (C1) area

//setBatchMode(true);
//run("Colors...", "foreground=black background=black selection=pink");
print("\\Clear");

// --------- Parameters -----------
// 1. file formats
file_format = "nd2";
save_format = "tif";

// 2. selecet chennels for ROI definition (typically C1 with nuclei) and 
// for the target that is going to be saved as a tif file with ROIs
dapi_channel = "C1";

// When images have only two channels, comment this out
bodipy_channel = "C2";
target_channel = "C3";

ROI_channel = dapi_channel;

// Predefine what segmented BODIPY image is called
LD_segmented = "LD_segmented";

// 3. Settings for autothreshold
// 3-1. Set Gaussian blur sigma and auto threshold method
gaussian_blur_sigma = 2;
thresholdMethod_nucleus = "Li"
thresholdMethod_BODIPY = "Otsu";

// 3-2. Set the min and max area of ROIs that are included into the 
min_size_of_roi = 50;
max_size_of_roi = 400;

// 3-2. Set the min and max area of lipid droplet
min_size_of_LD = 0.1;
max_size_of_LD = 10;

// 3-3. Choose if watershed is performed or not. Comment in and out either of Yes or No
watershed = "Yes";
//watershed = "No";

// 3-4. Choose if nuclear ROI on image edge is exluded or not. If yes, place " exclude". If no, place "" (blank)
exclude_or_not = " exclude"
//exclude_or_not = ""


// ------- Actual processing -------

// 1. Direct the user to define the folders for input and output
dataFolder = getDirectory("Choose the folder you want to process");
//wekaClassifierFolder = getDirectory("Choose where the classifier is");

// 2. Do analysis
// 2-1. Get the list of the files
filelist=getFileList(dataFolder);

// 2-2. Analyze indiviual files
for (i = 0; i < lengthOf(filelist); i++) {
	file=filelist[i];
	
	if (endsWith(file, file_format)) {
		// process and image analysis - see the function below
		print("About to analyze: " + file);
		analyzeImage();
		print("Finished analyzing: " + file);
	}
}

// 3. Let you know the end of analysis for all data
print("Finshed all analysis");



// --------- Functions ------------
// ----- Top-level functions-----
function analyzeImage() { 
	// function to anaylyze an given image file
	// 1. open the file
	open(file);


	// 2. Process image
	// 2-1. Max project and split channels
	maxProject_then_splitChannels();
	
	// 2-2. Segment from nuclei image and make ROIs
	createNuclearSegmentation(ROI_channel);
	
	// 2-3. Segment from BODIPY image
	segmentLD(bodipy_channel);
	
	// 3. Quantify LDs
	// Set measurement parameters
	run("Set Measurements...", "area redirect=" + LD_segmented + " decimal=3");
	
	// Number of nuclear ROIs that were generated in 2-2
	n_of_ROIs = roiManager("count");
	
	// Measure LDs in each ROI
	for (i = 0; i < n_of_ROIs; i++) {
		
		// Measure LDs
		selectWindow(LD_segmented);
		roiManager("Select", i);
		run("Analyze Particles...", "size=" + min_size_of_LD + "-" + max_size_of_LD + " show=Outlines display exclude include");
		
		// Add file name and ROI number to the result table
		for (j = 0; j < nResults; j++) {
			setResult("File name", j, file);
		}
		
		for (j = 0; j < nResults; j++) {
			setResult("ROI_number", j, i+1);
		}
		
		// Save the result
		selectWindow("Results");
		saveAs("Measurements", dataFolder + file + "_Results of ROI_" + i+1 + ".csv");
		
		// If there are 3 or more LDs in the ROI, save the image of measured LDs
		if (nResults > 2) {
			selectWindow("Drawing of " + LD_segmented);
			roiManager("Select", i);
			run("Flatten");
			saveAs("tif", dataFolder + file + "_Particles of ROI_" + i+1);
		}
		
		// clear results
		selectWindow("Drawing of " + LD_segmented);
		close();
		run("Clear Results");
	};
	
	
	// 4. Measure image of target (e.g. Sun2)
	measureImage();

	// 5. Clear results and ROIs and images
	run("Clear Results");
	run("Close All");

}

// ----- Second-level functions-----
function maxProject_then_splitChannels() { 
	// For a stack of images, max project and split channels to C1,C2,,,
	
	// 1. Get the number of channels
	getDimensions(width, height, channels, slices, frames);
	number_of_channels = channels;
	
	// 2. Max intesity Z project
	waitForUser("Decide Z project start and end points!");
	z_start = getNumber("Where Z section should start?", 1);
	z_end = getNumber("Where Z section should end?", 1);
	run("Z Project...", "start=" + z_start + " stop=" + z_end + " projection=[Max Intensity]");
	maxProjectedImage = getTitle();
	
	// 3. Split and rename each image to C1,C2,,,
	selectWindow(maxProjectedImage);
	run("Split Channels");
	for (i = 1; i < number_of_channels+1; i++) {
		selectWindow("C" + i + "-" + maxProjectedImage);
		rename("C" + i);
		run("Grays");
	}
}


function createNuclearSegmentation(channel) { 
	// Make a segmented binary image and ROIs

	// 1. Duplicate
	selectWindow(channel);
	run("Duplicate...", "title=segmented");

	// 2. Make a binary image
	run("Subtract Background...", "rolling=100");
	run("Gaussian Blur...", "sigma=" + gaussian_blur_sigma);
	setAutoThreshold(thresholdMethod_nucleus + " dark");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Open");
	run("Fill Holes");
	if (watershed == "Yes") {
		run("Watershed");
	};
	
	// 3. Make ROIs from the binary image
	run("Set Measurements...", "area mean shape redirect=None decimal=3");
	run("Analyze Particles...", "size=" + min_size_of_roi + "-" + max_size_of_roi + exclude_or_not + " include add");
}

function segmentLD(channel){
	// Segment BODIPY image into two classes: 1 for LD and 0 for else
	
	// Pre-process 
	selectWindow(channel);
	run("Duplicate...", " ");
	run("Subtract Background...", "rolling=40");
	run("Smooth");
	run("Duplicate...", " ");
	
	// Segment
	run("Auto Threshold", "method=" + thresholdMethod_BODIPY + " white");
	rename(LD_segmented);
	run("Duplicate...", " ");
	
	// Save the image
	saveImageWithROIs(LD_segmented);
	
}
	
function measureImage() { 
	// Measure mean intensity of each channel within ROI and ROI shape desriptors
	// Then save them to CSV
	// Finally save image with ROI displayed to tif

	// 1. get means from DAPI using "getMeans" function defined below
	dapi_means = getMeasureResult(dapi_channel, "Mean");

	// 2. redirect measurement to target
	run("Set Measurements...", "area mean shape redirect=" + target_channel + " decimal=3");
	
	// 3. measure mean in the target protein in all ROIs and ROI shape descriptors
	roiManager("deselect");
	roiManager("measure");
	
	// 4. add the nucleus channel mean data to the results
	for (i = 0; i < nResults; i++) {
		setResult("DAPI mean", i, dapi_means[i]);
	}
	
	// 5. add the file name to the results table
	for (i = 0; i < nResults; i++) {
		setResult("File name", i, file);
	}

	// 6. Save to CSV
	selectWindow("Results");
	saveAs("Measurements", dataFolder + "Results of " + file + ".csv");
	
	// 7. Save the image with ROI
	saveImageWithROIs(dapi_channel);

	// 8. Clear results and ROIs
	run("Clear Results");
	roiManager("deselect");
	roiManager("delete");
}

// ----- Third-level functions-----
function getMeasureResult(channel, item_name) { 
	// Measure the mean of the given channel within ROIs and return the results as an array

	// 1. redirect measurement to the channel
	run("Set Measurements...", "area mean redirect=" + channel + " decimal=3");
	
	// 2. measure mean of tag protein in all ROIs
	roiManager("Deselect");
	roiManager("Measure");
	
	// 3. store mean data to an array
	array = newArray(nResults);
	for (i = 0; i < nResults(); i++) {
	   array[i] = getResult(item_name, i);
	}
	
	// 4. clear the results
	run("Clear Results");

	// 5. return the result array
	return array;
}

function saveImageWithROIs(channel) { 
	// show ROIs on target, and save the image
	selectWindow(channel);
	roiManager("Show None");
	roiManager("Show All with labels");
	selectWindow(channel);
	run("Flatten");
	file_wo_format = replace(file, ".nd2", "");
	saveAs(save_format, dataFolder + file_wo_format + "_" + channel);
}