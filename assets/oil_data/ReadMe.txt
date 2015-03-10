1. File
	ReadMe.txt - This instruction file.
	mapping.txt - A mapping between the excel reports and the tables.
	schema.sql - The schema for the tables.
	sample_data - A folder including the sql sample data files are for the tables respectively.

(BTW, I noticed you have provided 6 reports, so I think actually there should be 6 tables rather than 5 which was specified in wiki)

2. In your VM, create a database in Vertica and connect it in your terminal.(Name the database as you like)

3. Use below command to create the table schema. (Assume you have uploaded my submission into your VM)
   {YOURDBNAME}=>\i {path_to_my_submission_root_folder}/scehma.sql

4. Use below command to insert data into crude_oil_and_petroleum table.
   {YOURDBNAME}=>\i {path_to_my_submission_root_folder}/sample_data/data_crude_oil_and_petroleum.sql

   You can use similar commands to load other data files into the tables.