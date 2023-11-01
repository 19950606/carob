# R script for "carob"

## ISSUES
# ....


carob_script <- function(path) {

"Description:

    [Farmers’ participatory researchers managed long-term trails aimed to improve the productivity, profitability, and sustainability of smallholder agriculture in the EGP by activities carried out to address the objectives: 1. Understand farmer circumstances with respect to cropping systems, natural and economic resources base, livelihood strategies, and capacity to bear risk and undertake technological innovation. 2. Develop with farmers more productive and sustainable technologies that are resilient to climate risks and profitable for small holders. 3. Facilitate widespread adoption of sustainable, resilient, and more profitable farming systems. (2018-02-18)]

"

	uri <- "hdl:11529/10547970"
	dataset_id <- carobiner::simple_uri(uri)
	group <- "fertilizer"
	## dataset level data 
	dset <- data.frame(
		dataset_id = dataset_id,
		group=group,
		project=NA,
		uri=uri,
		data_citation="Gathala, Mahesh K.; Tiwari, Thakur P.; Islam, Saiful; Chowdhury, Apurba K.; Bhattacharya, Prateek M.; Das, K.K.; Dhar, Tapamay; Pradhan, K.; Sinha, A.K.; Ghosh, Arunava; Mitra, B.; Chattopadhyay, C., 2018, '2.8-Rabi (winter) crops-all nodes-Long term trial (LT)-Malda-West Bengal', https://hdl.handle.net/11529/10547970, CIMMYT Research Data & Software Repository Network, V2",
		## if there is a paper, include the paper's doi here
		## also add a RIS file in references folder (with matching doi)
		publication= NA,
		data_institutions = "CIMMYT",
   		data_type="experiment", 
		carob_contributor="Mitchelle Njukuya",
		# date of first submission to carob
		carob_date="2023-10-10",
		revised_by="Robert Hijmans"
	)

## download and read data 
	ff  <- carobiner::get_data(uri, path, group)
	ff <- ff[-grep("^hdl", basename(ff))]
	js <- carobiner::get_metadata(dataset_id, path, group, major=2, minor=1)
	dset$license <- carobiner::get_license(js)


	get_raw_data <- function(f) {
		if (basename(f) == "Rabi Maize 2016-17-LT-all nodes-Malda.xlsx") {
			skip1 = 3
		} else {
			skip1=4
		}
		r1 <- carobiner::read.excel.hdr(f, sheet ="4- Stand counts & Phenology", skip=skip1, hdr=2)
		r2 <- carobiner::read.excel.hdr(f, sheet ="14 - Grain Harvest ", skip=4, hdr=2)
		r3 <- carobiner::read.excel.hdr(f, sheet ="6 - Fertilizer amounts ", skip=4, hdr=2)

		colnames(r2) <- gsub("Calculation_", "", colnames(r2))
		colnames(r2) <- gsub("Straw.Stover.yield.t.ha" , "Straw.yield.t.ha" , colnames(r2))
		
		nms <- c("Site.No", "Tmnt", "Grain.yield.t.ha", "TGW.g", "Biomass.t.ha", "Straw.yield.t.ha")
		r2 <- r2[, nms]
		
		colnames(r3) <- gsub("Kg.ha_N.kg.ha", "N.kg.ha", colnames(r3))
		nms <- c("Site.No", "Tmnt", "N.kg.ha", "P2O5.kg.ha", "K2O.kg.ha", "Gypsum.kg.ha", "ZnSO4.kg.ha", "Boric.acid.kg.ha", grep("Product.used", names(r3), value=TRUE))
		r3 <- r3[, nms]

		r <- merge(r1, r2, by=c("Site.No", "Tmnt"))
		merge(r, r3, by=c("Site.No", "Tmnt"))
	}


#################################################### 4- Stand counts & Phenology #############################################	

	process_data <- function(r) {

		## do not do this and then subset
		#	d <- r
		# rather start a new data.frame
	   d <- data.frame(
			trial_id = as.character(r$Trial.Code), 
			treatment = r$Tmnt,
			crop=tolower(r$Crop), variety= r$Variety, 
			season=r$Season, 
			biomass_total = r$Biomass.t.ha * 1000,
			residue_yield = r$Straw.yield.t.ha * 1000,
			yield = r$Grain.yield.t.ha * 1000,
			emergence= r$X100.emergence.DAS,
			flowering= r$X50.anthesis.DAS,
			maturity = r$X80.physiological.maturity.DAS,
			dataset_id = dataset_id,
			N_fertilizer = r$N.kg.ha,
			P_fertilizer = r$P2O5.kg.ha / 2.29,
			K_fertilizer = r$K2O.kg.ha / 1.2051,
			B_fertilizer = r$Boric.acid.kg.ha * 0.1748,
			S_fertilizer = 0,
			Zn_fertilizer = 0,
			lime = 0,
			gypsum = 0
		)

		i <- grep("Date.of.seeding", names(r))
		d$planting_date = as.character(as.Date(r[,i]))
		i <- grep("Dat..of.harvest", names(r))
		d$harvest_date = as.character(as.Date(r[,i]))			

		d$on_farm <- TRUE
		d$is_survey <- FALSE 
		d$irrigated <- TRUE
		d$inoculated <- FALSE
		d$yield_part <- "grain"

		d$country <- "India"
		d$adm1 <- "West Bengal"
		d$adm2 <- "Malda"
		d$location <- r$Node
		
	##### Fertilizer ########
		frp <- apply(r[, grep("Product.used", names(r), value=TRUE)], 1, 
			function(i) paste(unique(i[!is.na(i)]), collapse="; "))
		
		# the excel file has encoded 10:26:26 as "time"!
		frp <- gsub("1899-12-31 10:26:26", "NPK", frp)
		frp <- gsub("UREA", "urea", frp)
		frp <- gsub("Urea", "urea", frp)
		frp <- gsub("MoP", "KCl", frp)
		frp <- gsub("Boron 20%", "Borax", frp) #?
		frp <- gsub("Borax 21", "Borax", frp)
		frp <- gsub("Boron", "Borax", frp) #?
		frp[frp == ""] <- NA
		d$fertilizer_type <- frp
		d
	}


	fun <- function(f) {
		#print(basename(f)); flush.console()
		r <- get_raw_data(f)
		d <- process_data(r)

		d$longitude <- NA
		d$latitude <- NA
		d$longitude [d$location =="Mahadipur"] <- 88.1265
		d$latitude [d$location =="Mahadipur"] <- 24.8501 
		d$longitude [d$location =="Bidyanandapur"] <- 87.9903
		d$latitude [d$location =="Bidyanandapur"] <- 25.9517
		d$longitude [d$location =="Urgitola"] <- 88.1411
		d$latitude [d$location =="Urgitola"] <- 25.0108

		d
	}
	
	dd <- lapply(ff, fun)
	dd <- do.call(rbind, dd)
	dd$crop <- gsub("kidneybean", "kidney bean", dd$crop)

	carobiner::write_files(dset, dd, path=path)
}
