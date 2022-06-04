using Godot;
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using LiteDB;
using ImageMagick;
using Alphaleonis.Win32.Filesystem;

/*
	Apparently LiteDB does not support ulong, only long
		1. convert all ulong to long 
			- still not entirely sure if this is always safe/accurate
			
		2. convert with (long) before checking database and convert with (ulong) for internal comparisons
			- requires far more conversions
		
		3. abandon long entirely and just leave everything as a string
			+ ensures accuracy
			- might use more space in memory/on disk
		
	Also I just realized that LiteDB does not actually use an index for _Id, and even if it did it would not be all that 
	useful for selecting a range.So the question of whether to change the _Id is now moot and I should probably set it to komihash after all.
	This means I still have to figure out a way to select a numbered range of rows from the database (with a given start point).
	It does automatically convert them back to ulong when retrieving them from the database so I should only need to convert them for comparison (may not even need to, needs testing)
*/

public class KomiHashInfo {
	//public int id { get; set; }
	public ulong komihash { get; set; }
	public bool filter { get; set; }
	public HashSet<string> paths { get; set; }
	public HashSet<string> tags { get; set; }
}

public class Database : Node {
	// need to do a speed comparsion between
	// 		col.FindById(sha256);
	// and 
	//		col.FindOne(Query.EQ("sha256", sha256))
	// if they are about the same or 2nd one is faster I will leave the Ids as numbers and add a sha256 variable
	// if the first one is significantly faster then I will instead add an index variable to the class and use sha256 as the id
	
	public bool use_journal = true;
	//private int index = 0; // If I have to use this for Query.Between() then I need to store it in a database
	
	public string metadata_path;
	public void SetMetadataPath(string path) { metadata_path = path; }
	
	
	public LiteDatabase db_komihash;
	public ILiteCollection<KomiHashInfo> col_komihash;
	public Dictionary<ulong, KomiHashInfo> komihash_info = new Dictionary<ulong, KomiHashInfo>();
	
	public int Create() {
		try {
			if (use_journal) {
				db_komihash = new LiteDatabase(metadata_path + "komihash_info.db");
				// not needed if FindOne() is faster or the same (actually the main reason I did this was to prevent duplicates)
				// it should be possible to just check if anything in the database has a matching hash, but that will likely be considerably slower
				//BsonMapper.Global.Entity<KomiHashInfo>().Id(x => x.komihash);		
				col_komihash = db_komihash.GetCollection<KomiHashInfo>("komihashes");
			}
			return 0;
		}
		catch (Exception ex) { GD.Print("Database::Create() : ", ex); return 1; }
	}
	public void Destroy() {
		db_komihash.Dispose();
	}
	
	public void CheckpointKomiHash() { db_komihash.Checkpoint(); }
	
	public void LoadAllKomiHash() {
		try {
			var komihashes = col_komihash.FindAll();
			if (komihashes != null) 
				foreach (KomiHashInfo khash in komihashes) 
					komihash_info[khash.komihash] = khash;
		} 
		catch (Exception ex) { GD.Print("Database::LoadAllKomiHash() : ", ex); }
	}
	
	/* LoadRangeSHA256()
	 * DESC: loads a number of Komihashes from the Database into komihash_info starting at 'start'+1
	 * TODO: add options related to filtering and sorting (needs to be done on the database if I am only retrieving a section of the shas)
	*/
	public void LoadRangeKomiHash(int start, int number) {
		try {
			var komihashes = col_komihash.Find(Query.All(), start, limit:number);
			if (komihashes != null) 
				foreach (KomiHashInfo khash in komihashes)
					komihash_info[khash.komihash] = khash;
		}
		catch (Exception ex) { GD.Print("Database::LoadRangeKomiHash() : ", ex); } 
	}	
	
	public int InsertKomiHashInfo(ulong komihash1, bool filter1, string[] paths1, string[] tags1) {
		try {
			if (col_komihash.FindOne(Query.EQ("komihash", (long)komihash1)) != null) return 1; // duplicate
			var komihash_info = new KomiHashInfo {
				komihash = komihash1,
				filter = filter1,
				paths = new HashSet<string>(paths1),
				tags = new HashSet<string>(tags1)
			};
			col_komihash.Insert(komihash_info);
			return 0;
		}
		//catch (SomeSpecificException sse) {}
		catch (Exception ex) { GD.Print("Database::InsertKomiHashInfo() : ", ex); return -1; }
	}
	
	// having to do this is a strong reason to just switch everything to string
	public string[] GetKomi64s() { 
		var komi64s = new List<string>();
		foreach (ulong komi64 in komihash_info.Keys.ToArray())
			komi64s.Add(Convert.ToString(komi64));
		return komi64s.ToArray();		 
	}
	// yet more reasons to switch to a string representation
	public bool GetFilterKomi(string hash) { return (komihash_info.ContainsKey(ulong.Parse(hash))) ? komihash_info[ulong.Parse(hash)].filter : false; }
	public string[] GetPathsKomi(string hash) { return (komihash_info.ContainsKey(ulong.Parse(hash))) ? (komihash_info[ulong.Parse(hash)].paths != null) ? komihash_info[ulong.Parse(hash)].paths.ToArray() : new string[0] : new string[0]; } /* returns empty string array if paths is null or key is not found, otherwise returns the paths array */
	public string[] GetTagsKomi(string hash) { return (komihash_info.ContainsKey(ulong.Parse(hash))) ? (komihash_info[ulong.Parse(hash)].tags != null) ? komihash_info[ulong.Parse(hash)].tags.ToArray() : new string[0] : new string[0]; }
	/* not 100% sure the above 2 lines work yet, but it does not have any compile errors (never used encapsulated ternary operators before) */
	
}
