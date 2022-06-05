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
public class ImportInfo {
	public string import_id { get; set; }
	public string import_name { get; set; }
	public string import_base_folder { get; set; }
	public DateTime import_time { get; set; } // could have it be import_time_utc with DateTime.UtcNow but I don't think this is needed for imports
	public int import_count { get; set; }
}
public class ImportList {
	public string import_id { get; set; }
	public HashSet<string> import_list { get; set; }
}

public class Database : Node {
	public bool use_journal = true;	
	public string metadata_path;
	public void SetMetadataPath(string path) { metadata_path = path; }
	
	public LiteDatabase db_komi64;
	public LiteDatabase db_import;
	
	public ILiteCollection<Komi64Info> col_komi64;
	public ILiteCollection<ImportInfo> col_import_info;
	public ILiteCollection<ImportList> col_import_list;
	
	public Dictionary<string, Komi64Info> dict_komi64 = new Dictionary<string, Komi64Info>();
	public List<string> komi_hashes = new List<string>();
	
	public Dictionary<string, ImportInfo> dict_import_info = new Dictionary<string, ImportInfo>();

	public int Create() {
		try {
			if (use_journal) {
				db_komi64 = new LiteDatabase(metadata_path + "komi64_info.db");
				BsonMapper.Global.Entity<Komi64Info>().Id(x => x.komi64);		
				col_komi64 = db_komi64.GetCollection<Komi64Info>("komihashes");
				
				db_import = new LiteDatabase(metadata_path + "import_info.db");
				BsonMapper.Global.Entity<ImportInfo>().Id(x => x.import_id);
				BsonMapper.Global.Entity<ImportList>().Id(x => x.import_id);
				col_import_info = db_import.GetCollection<ImportInfo>("import_info");
				col_import_list = db_import.GetCollection<ImportList>("import_list");
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
	
	// var count = collection.Count(Query.EQ("Name", "John Doe"));
	public int GetTotalRowCountKomi() { return col_komi64.Count(Query.All()); }
	
	public void LoadAllKomi64() {
		try {
			var komihashes = col_komi64.FindAll();
			if (komihashes != null) 
				foreach (Komi64Info khinfo in komihashes)
					dict_komi64[khinfo.komi64] = khinfo;
		} 
		catch (Exception ex) { GD.Print("Database::LoadAllKomi64() : ", ex); }
	}
	
	/* DESC: loads a number of Komihashes from the Database into komihash_info starting at 'start'+1
	 * TODO: add options related to filtering and sorting (needs to be done on the database if I am only retrieving a section of the shas)*/
	public void LoadRangeKomi64(int start, int number) {
		try {
			var komihashes = col_komi64.Find(Query.All(), start, limit:number);
			if (komihashes != null) 
				foreach (Komi64Info khinfo in komihashes) {
					dict_komi64[khinfo.komi64] = khinfo;
					komi_hashes.Add(khinfo.komi64);
				}
		}
		catch (Exception ex) { GD.Print("Database::LoadRangeKomi64() : ", ex); } 
	}	
		
	public int InsertKomi64Info(string komi64_n, bool filter_n, string[] paths_n, string[] tags_n) {
		try {
			var temp = col_komi64.FindOne(Query.EQ("_Id", komi64_n));
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
	
	public string[] GetTempKomi64List() {
		string[] komi64s = komi_hashes.ToArray();
		komi_hashes.Clear();
		return komi64s;
	}
	public string[] GetAllKomi64FromDict() { return dict_komi64.Keys.ToArray(); }
	public bool GetKomiFilterFromDict(string komi64) { return (dict_komi64.ContainsKey(komi64)) ? dict_komi64[komi64].filter : false; }
	public string[] GetKomiPathsFromDict(string komi64) { return (dict_komi64.ContainsKey(komi64)) ? (dict_komi64[komi64].paths != null) ? dict_komi64[komi64].paths.ToArray() : new string[0] : new string[0]; }
	public string[] GetKomiTagsFromDict(string komi64) { return (dict_komi64.ContainsKey(komi64)) ? (dict_komi64[komi64].tags != null) ? dict_komi64[komi64].tags.ToArray() : new string[0] : new string[0]; }
	public void RemoveKomi64sFromDict(string[] komi64s) {
		foreach (string komi64 in komi64s)
			dict_komi64.Remove(komi64);
	}
	
	public int LoadAllImportInfoFromDatabase() {
		try {
			var imports = col_import_info.FindAll();
			foreach (ImportInfo import in imports)
				dict_import_info[import.import_id] = import;
			return 0;
		}
		catch (Exception ex) { GD.Print("Database::LoadAllImportInfoFromDatabase() : ", ex); return 1; }
	}
	public string[] GetAllImportIDsFromDict() {
		try { return dict_import_info.Keys.ToArray(); }
		catch (Exception ex) { GD.Print("Database::GetAllImportNamesFromList() : ", ex); return new string[0]; }
	}
	public bool ImportDictHasID(string import_id) { return dict_import_info.ContainsKey(import_id); }
	public string GetImportNameFromDict(string import_id) { return dict_import_info[import_id].import_name; }
	public string GetImportBaseFolder(string import_id) { return dict_import_info[import_id].import_base_folder; }
	public DateTime GetImportTime(string import_id) { return dict_import_info[import_id].import_time; }
	public int GetImportCount(string import_id) { return dict_import_info[import_id].import_count; } 
	public string[] GetImportListFromDatabase(string import_id) {
		// logical issue with this, basically I have to decide between the following:
		//		1. store like it is currently import_id:List(komi64) 
		//		2. store them as _Id:import_id:komi64
		// 1. has the problem of using a lot of memory if someone just picks a top-level directory and imports 10's of millions of images at once
		// 2. has the problem of being slower and using more storage space, though I do not know how much slower/more space
		try {
			var imports = col_import_list.FindOne(Query.EQ("_Id", import_id));
			return imports.import_list.ToArray();
		}
		catch (Exception ex) { GD.Print("Database::GetImportListFromDatabase() : ", ex); return new string[0]; }
	}
	// see comments in GetImportListFromDatabase(), not possible to do this with the current implementation (unless I load them all into memory first anyways)
	//public string[] GetSubsetOfImportListFromDatabase(string import_id) {}
	
	public void AddImportToDatabase(string name_n, string base_folder, string[] list) {
		try {
			string iid = GetRandomID(16); // gets a random 128 bit ID
			var iinfo = new ImportInfo {
				import_id = iid, 
				import_name = name_n,
				import_base_folder = base_folder,
				import_time = DateTime.Now,
				import_count = list.Length
			};
			col_import_info.Insert(iinfo);
			var ilist = new ImportList {
				import_id = iid,
				import_list = new HashSet<string>(list)
			};
			col_import_list.Insert(ilist);
		}
		catch (Exception ex) { GD.Print("Database::AddImportToDatabase() : ", ex); return; } 
	}
	
	public string GetRandomID(int num_bytes) {
		try{
			byte[] bytes = new byte[num_bytes];
			var rng = new RNGCryptoServiceProvider();
			rng.GetBytes(bytes);
			rng.Dispose();
			return BitConverter.ToString(bytes);
		}
		catch (Exception ex) { GD.Print("Database::GetRandomID() : ", ex); return ""; } 
	}
}
