using Godot;
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using LiteDB;
using ImageMagick;
using Alphaleonis.Win32.Filesystem;

public class Komi64Info {
	public string komi64 { get; set; }
	public bool filter { get; set; }
	public HashSet<string> paths { get; set; }
	public HashSet<string> tags { get; set; }
}
/* stores the metadata of an import */
public class ImportInfo {
	public string import_id { get; set; }				// the 32 bit ID of the import group
	public string import_name { get; set; }				// the user-defined name of the import group
	public string import_base_folder { get; set; }		// the folder that the import started at
	public long import_time { get; set; }				// the time that the import was started (completed?) (in ticks)
	public int import_count { get; set; }				// the total number of images imported for this group
	public int import_fail_count { get; set; }			// the total number of images that failed to import for this group
	public int import_duplicate_count { get; set; }		// the total number of duplicate images for this group		[A,A,V,F,C,F,A,B,H] = 3 (A,A,F)
}
/* these will be members of a collection, with collection_name == import_id */
public class ImportGroup {
	public string komi64 { get; set; }					// the komi64 hash of the image
	public string file_path { get; set; }				// the first found file path of the image in this import
	public long file_size { get; set; }					// the file size of the image
	public long file_creation_utc { get; set; }			// the time (UTC) that the file was created (in ticks)
}

public class SortBy {
	public const int FileHash = 0;			
	public const int FilePath = 1;			
	public const int FileSize = 2;			
	public const int FileCreationUtc = 3;
}

// there are ~4000 bytes total of space for collection names in a database, with each import_id taking 8 bytes; I will set the limit of the number of import_groups to ~400
// I think EnsureIndex() might be a way around checking if class fields are null

public class Database : Node {
	public bool use_journal = true;	
	public string metadata_path;
	public void SetMetadataPath(string path) { metadata_path = path; }
	
	public LiteDatabase db_komi64;
	public LiteDatabase db_import;
	
	public ILiteCollection<Komi64Info> col_komi64;
	public ILiteCollection<ImportInfo> col_import_info;
	
	public Dictionary<string, Komi64Info> dict_komi64 = new Dictionary<string, Komi64Info>();
	public Dictionary<string, ImportInfo> dict_import_info = new Dictionary<string, ImportInfo>();
	public Dictionary<string, ImportGroup> dict_import_group = new Dictionary<string, ImportGroup>();
	
	public int Create() {
		try {
			if (use_journal) {
				db_komi64 = new LiteDatabase(metadata_path + "komi64_info.db");
				BsonMapper.Global.Entity<Komi64Info>().Id(x => x.komi64);		
				col_komi64 = db_komi64.GetCollection<Komi64Info>("komihashes");
				
				db_import = new LiteDatabase(metadata_path + "import_info.db");
				BsonMapper.Global.Entity<ImportInfo>().Id(x => x.import_id);
				BsonMapper.Global.Entity<ImportGroup>().Id(x => x.komi64);
				col_import_info = db_import.GetCollection<ImportInfo>("import_info");
				//col_import_list = db_import.GetCollection<ImportList>("import_list");
			}
			return 0;
		}
		catch (Exception ex) { GD.Print("Database::Create() : ", ex); return 1; }
	}
	public void Destroy() { 
		db_komi64.Dispose(); 
		db_import.Dispose();
	}
	public void CheckpointKomi64() { db_komi64.Checkpoint(); }
	public void CheckpointImport() { db_import.Checkpoint(); }
	
/*=========================================================================================
									   IMPORT INFO
=========================================================================================*/	
	// loads everything from the "import_info" collection into dict_import_info
	public int LoadImportInfoFromDatabase() {
		try {
			var imports = col_import_info.FindAll();
			foreach (ImportInfo import in imports) {
				if (import.import_name == null) import.import_name = ""; // prevents a crash caused by the database storing "" as null
				dict_import_info[import.import_id] = import;
			} return 0;
		} catch (Exception ex) { GD.Print("Database::LoadImportInfoFromDatabase() : ", ex); return 1; }
	}
	// returns the keys in dict_import_info
	public string[] GetImportIDsFromDict() { return dict_import_info.Keys.ToArray(); }
	// checks if dict_import contains the key import_id
	public bool ImportDictHasID(string import_id) { return dict_import_info.ContainsKey(import_id); } 
	
	public string GetImportNameFromID(string import_id) { return dict_import_info[import_id].import_name; }
	public string GetImportFolderFromID(string import_id) { return dict_import_info[import_id].import_base_folder; }
	// what exactly I might want to get from Date/Time is a bit more complex
	public int GetImportSuccessCountFromID(string import_id) { return dict_import_info[import_id].import_count; }
	public int GetImportFailCountFromID(string import_id) { return dict_import_info[import_id].import_fail_count; }
	public int GetImportDuplicateCountFromID(string import_id) { return dict_import_info[import_id].import_duplicate_count; }
	
	public void IncrementImportSuccessCount(string import_id) { dict_import_info[import_id].import_count++; }
	public void IncrementImportFailCount(string import_id) { dict_import_info[import_id].import_fail_count++; }
	public void IncrementImportDuplicateCount(string import_id) { dict_import_info[import_id].import_duplicate_count++; }
	
	public void AddImportInfoToDatabase(string iid, string iname, string ifolder) {
		try {
			var iinfo = new ImportInfo {
				import_id = iid,
				import_name = iname,
				import_base_folder = ifolder,
				import_time = DateTime.Now.Ticks,
				import_count = 0,
				import_fail_count = 0,
				import_duplicate_count = 0				
			};
			dict_import_info[iid] = iinfo;
			col_import_info.Insert(iinfo); // need to update when program closes or import finishes
		}
		catch (Exception ex) { GD.Print("Database::AddImportInfoToDatabase() : ", ex); return; }
	}
	public void UpdateImportInfo(string import_id) {
		try { col_import_info.Update(dict_import_info[import_id]); }
		catch (Exception ex) { GD.Print("Database::UpdateImportInfo() : ", ex); return; }	
	}
	public void UpdateAllImportInfo() { foreach (string iid in dict_import_info.Keys.ToArray()) UpdateImportInfo(iid); }
	
	public void DeleteImportInfoByID(string import_id) {
		try {
			col_import_info.Delete(import_id);
		}
		catch (Exception ex) { GD.Print("Database::DeleteImportInfoByID() : ", ex); return; }	
	}
	public void DropImportTableByID(string import_id) { db_import.DropCollection(import_id); }
	
/*=========================================================================================
									  IMPORT GROUP
=========================================================================================*/	
	public string[] GetImportGroupRange(string import_id, int start, int count, int sort_by=SortBy.FileHash, bool ascend=false) {
		// clears dict_import_group, loads the specifed range of ImportGroups into dict_import_group, then returns the komi64 keys
		try {
			var col = db_import.GetCollection<ImportGroup>(import_id);
			var list_komi64 = new List<string>();
			dict_import_group.Clear();
			IEnumerable<ImportGroup> imports;
			
			if (sort_by == SortBy.FilePath) {
				if (ascend) imports = col.Find(Query.All("file_path", Query.Ascending), start, limit:count);
				else imports = col.Find(Query.All("file_path", Query.Descending), start, limit:count);
			}
			else if (sort_by == SortBy.FileSize) {
				if (ascend) imports = col.Find(Query.All("file_size", Query.Ascending), start, limit:count);
				else imports = col.Find(Query.All("file_size", Query.Descending), start, limit:count);
			}
			else if (sort_by == SortBy.FileCreationUtc) {
				if (ascend) imports = col.Find(Query.All("file_creation_utc", Query.Ascending), start, limit:count);
				else imports = col.Find(Query.All("file_creation_utc", Query.Descending), start, limit:count);
			}
			else  { // SortBy.FileHash
				if (ascend) imports = col.Find(Query.All(), start, limit:count);//imports = col.Find(Query.All(Query.Ascending), start, limit:count);
				else imports = col.Find(Query.All(Query.Descending), start, limit:count);
			}
					
			foreach (ImportGroup import in imports) {
				dict_import_group[import.komi64] = import;
				list_komi64.Add(import.komi64);
			} 
			return list_komi64.ToArray();	
		} 
		catch (Exception ex) { GD.Print("Database::GetImportGroupRange() : ", ex); return new string[0]; }
	}
	public string GetFileSizeFromHash(string komi64) { return dict_import_group[komi64].file_size.ToString(); }
	public void InsertImportGroup(string iid, string ikomi, string ipath, long isize, long itimeUTC) {
		try {
			var col = db_import.GetCollection<ImportGroup>(iid);
			var temp = col.FindById(ikomi);
			// Update() is not necessary for this data type
			if (temp == null) {
				var igroup = new ImportGroup {
					komi64 = ikomi,
					file_path = ipath,
					file_size = isize,
					file_creation_utc = itimeUTC
				};
				col.Insert(igroup);
			}
		}
		catch (Exception ex) { GD.Print("Database::InsertImportGroup() : ", ex); return; }	
	}
	public bool ImportGroupHasKomi(string import_id, string komi64) {
		try {
			var col = db_import.GetCollection<ImportGroup>(import_id);
			var temp = col.FindById(komi64);
			if (temp != null) return true;
			return false;
		}
		catch (Exception ex) { GD.Print("Database::ImportGroupHasKomi() : ", ex); return false; }	
	}
	
/*=========================================================================================
										 MISC
=========================================================================================*/	
	public string GetRandomID(int num_bytes) {
		try{
			byte[] bytes = new byte[num_bytes];
			var rng = new RNGCryptoServiceProvider();
			rng.GetBytes(bytes);
			rng.Dispose();
			return BitConverter.ToString(bytes).Replace("-", "");
		}
		catch (Exception ex) { GD.Print("Database::GetRandomID() : ", ex); return ""; } 
	}

/*=========================================================================================
									KOMI (UNORGANIZED)
=========================================================================================*/	
	// var count = collection.Count(Query.EQ("Name", "John Doe"));
	public int GetTotalRowCountKomi() { return col_komi64.Count(Query.All()); }
	
	/* DESC: loads a number of Komihashes from the Database into komihash_info starting at 'start'+1
	 * TODO: add options related to filtering and sorting (needs to be done on the database if I am only retrieving a section of the shas)*/
	public void LoadRangeKomi64(int start, int number) {
		try {
			var komihashes = col_komi64.Find(Query.All(), start, limit:number);
			if (komihashes != null) 
				foreach (Komi64Info khinfo in komihashes)
					dict_komi64[khinfo.komi64] = khinfo;
		}
		catch (Exception ex) { GD.Print("Database::LoadRangeKomi64() : ", ex); } 
	}	
	
	public void LoadOneKomi64(string komi64) {
		try {
			//var khinfo = col_komi64.FindOne(Query.EQ("_Id", komi64));
			var khinfo = col_komi64.FindById(komi64);
			if (khinfo != null) dict_komi64[komi64] = khinfo;
		}
		catch (Exception ex) { GD.Print("Database::LoadOneKomi64() : ", ex); } 
	}
		
	public int InsertKomi64Info(string komi64_n, bool filter_n, string[] paths_n, string[] tags_n) {
		try {
			//var temp = col_komi64.FindOne(Query.EQ("_Id", komi64_n));
			var temp = col_komi64.FindById(komi64_n);
			if (temp != null) {
				bool changed = false;
				foreach (string path in paths_n) {
					if (!temp.paths.Contains(path)) { 
						temp.paths.Add(path);
						changed = true;
					}
				}
				if (changed) col_komi64.Update(temp);
				return 1; // duplicate
			}
			else {
				var komi64_info = new Komi64Info {
					komi64 = komi64_n,
					filter = filter_n,
					paths = new HashSet<string>(paths_n),
					tags = new HashSet<string>(tags_n)
				};
				col_komi64.Insert(komi64_info);
				return 0;
			}
		}
		//catch (SomeSpecificException sse) {}
		catch (Exception ex) { GD.Print("Database::InsertKomi64Info() : ", ex); return -1; }
	}
	
	public bool GetKomiFilterFromDict(string komi64) { return (dict_komi64.ContainsKey(komi64)) ? dict_komi64[komi64].filter : false; }
	public string[] GetKomiPathsFromDict(string komi64) { return (dict_komi64.ContainsKey(komi64)) ? (dict_komi64[komi64].paths != null) ? dict_komi64[komi64].paths.ToArray() : new string[0] : new string[0]; }
	public string[] GetKomiTagsFromDict(string komi64) { return (dict_komi64.ContainsKey(komi64)) ? (dict_komi64[komi64].tags != null) ? dict_komi64[komi64].tags.ToArray() : new string[0] : new string[0]; }
	public void RemoveKomi64sFromDict(string[] komi64s) {
		foreach (string komi64 in komi64s)
			dict_komi64.Remove(komi64);
	}
}
