using Godot;							// access to Godot
using System;							// access to System
using System.IO;						// (?)
using System.Linq;						// everything related to the database
using System.Linq.Expressions;			// Predicate Builder
using System.Collections.Generic;		// HashSet, Dictionary
using System.Diagnostics;				// Stopwatch
using System.Reflection;				// needed for x.GetType().GetProperty(column_name).GetValue(x, null) (I think)
using System.Security.Cryptography;		// (?)
using LiteDB;							// everything related to the database
using ImageMagick;						// (?)
using Alphaleonis.Win32.Filesystem;		// (?)

/*=========================================================================================
										 CLASSES
=========================================================================================*/

	/* stores the metadata for a specific image */
	public class Komi64Info {
		public string komi64 { get; set; }					// the 64bit komi hash of the image
		public bool filter { get; set; }					// whether the image should be filtered (this will be replaced with a settings FLAG)(if I allow settings on an individual image basis)
		public long file_size { get; set; }					// the file size of the image in bytes
		public long file_creation_utc { get; set; }			// the UTC time that the image was created, in Ticks
		public HashSet<string> paths { get; set; }			// the set of all file_paths that the image can be found at
		public HashSet<string> tags { get; set; }			// the set of all tags applied to this image (may be split up into multiple sets)
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

	/* stores the metadata for a group of related images */
	public class ImageGroupInfo {
		public string group_id { get; set; }				// the (??) ID of the group
		public int count { get; set; }						// the total number of images in this group
		public HashSet<string> images { get; set; }			// the set of all komi hashes that are members of this image group
		public HashSet<string> tags { get; set; }			// the tags applied to this group as a whole (not its individual members)
		// might be more metadata like the type of group (user-defined) (comic being an example);; public string group_type { get; set; } // group_type = "Comic";
		// user would be able to define the accepted types in a menu somewhere, then they can select them in a drop-down while creating the group
	}

	/**/
	public class ImageGroupMetadata {
		public string database_file_path { get; set; }		// the path to the database
		public int table_names_total_length { get; set; }	// the sum total of all table names in the database
	}

	/* class may not be needed; will be stored in a table named with the group_id */
	public class ImportGroups {
		public string komi64 { get; set; }	
	}

	public class TagInfo {
		public string tag { get; set; }
		public HashSet<string> hashes { get; set; }
	}

	public class SortBy {
		// need to turn these into flags
		public const int FileHash = 0;			
		public const int FilePath = 1;			
		public const int FileSize = 2;			
		public const int FileCreationUtc = 3;
		public const int Random = 4; 
	}
	
	public class ErrorCodes {
		public const int OK = 0;
		public const int ERROR = 1;
		public const int DUPLICATE = 2;
		public const int INT_ERROR = -1;
	}
	
	// https://petemontgomery.wordpress.com/2011/02/10/a-universal-predicatebuilder/
	public static class PredicateBuilder{
		public static System.Linq.Expressions.Expression<Func<T, bool>> True<T>() { return param => true; }
		public static System.Linq.Expressions.Expression<Func<T, bool>> False<T>() { return param => false; }
		public static System.Linq.Expressions.Expression<Func<T, bool>> Create<T>(System.Linq.Expressions.Expression<Func<T, bool>> predicate) { return predicate; }
	
		public static System.Linq.Expressions.Expression<Func<T, bool>> And<T>(this System.Linq.Expressions.Expression<Func<T, bool>> first, System.Linq.Expressions.Expression<Func<T, bool>> second)
		{
			return first.Compose(second, System.Linq.Expressions.Expression.AndAlso);
		}
		public static System.Linq.Expressions.Expression<Func<T, bool>> Or<T>(this System.Linq.Expressions.Expression<Func<T, bool>> first, System.Linq.Expressions.Expression<Func<T, bool>> second)
		{
			return first.Compose(second, System.Linq.Expressions.Expression.OrElse);
		}
		public static System.Linq.Expressions.Expression<Func<T, bool>> Not<T>(this System.Linq.Expressions.Expression<Func<T, bool>> expression)
		{
			var negated = System.Linq.Expressions.Expression.Not(expression.Body);
			return System.Linq.Expressions.Expression.Lambda<Func<T, bool>>(negated, expression.Parameters);
		}
		static System.Linq.Expressions.Expression<T> Compose<T>(this System.Linq.Expressions.Expression<T> first, System.Linq.Expressions.Expression<T> second, Func<System.Linq.Expressions.Expression, System.Linq.Expressions.Expression, System.Linq.Expressions.Expression> merge)
		{
			// zip parameters (map from parameters of second to parameters of first)
			var map = first.Parameters
				.Select((f, i) => new { f, s = second.Parameters[i] })
				.ToDictionary(p => p.s, p => p.f);
	 
			// replace parameters in the second lambda expression with the parameters in the first
			var secondBody = ParameterRebinder.ReplaceParameters(map, second.Body);
	 
			// create a merged lambda expression with parameters from the first expression
			return System.Linq.Expressions.Expression.Lambda<T>(merge(first.Body, secondBody), first.Parameters);
		}
	 
		class ParameterRebinder : ExpressionVisitor
		{
			readonly Dictionary<ParameterExpression, ParameterExpression> map;
	 
			ParameterRebinder(Dictionary<ParameterExpression, ParameterExpression> map)
			{
				this.map = map ?? new Dictionary<ParameterExpression, ParameterExpression>();
			}
	 
			public static System.Linq.Expressions.Expression ReplaceParameters(Dictionary<ParameterExpression, ParameterExpression> map, System.Linq.Expressions.Expression exp)
			{
				return new ParameterRebinder(map).Visit(exp);
			}
	 
			protected override System.Linq.Expressions.Expression VisitParameter(ParameterExpression p)
			{
				ParameterExpression replacement;
	 
				if (map.TryGetValue(p, out replacement))
				{
					p = replacement;
				}
	 
				return base.VisitParameter(p);
			}
		}
	}
	
	public static class LinqExtensions {
		public static IOrderedEnumerable<TSource> OrderBy<TSource, TKey>(this IEnumerable<TSource> source, Func<TSource, TKey> keySelector, bool ascend) {
			return ascend ? source.OrderBy(keySelector) : source.OrderByDescending(keySelector);
		}
		
		public static bool ContainsAny<T>(this IEnumerable<T> sequence, params T[] matches)
		{
			return matches.Any(value => sequence.Contains(value));
		}

		public static bool ContainsAll<T>(this IEnumerable<T> sequence, params T[] matches)
		{
			return matches.All(value => sequence.Contains(value));
		}		
	}
	
// there are ~4000 bytes total of space for collection names in a database, with each import_id taking 8 bytes; I will set the limit of the number of import_groups to ~400
// I think EnsureIndex() might be a way around checking if class fields are null

public class Database : Node {
	public bool use_journal = true;	
	public string metadata_path;
	public void SetMetadataPath(string path) { metadata_path = path; }
	
	public int last_query_count = 0;
	public int GetTagQueryCount() { return last_query_count; }	
	
	public LiteDatabase db_komi64;
	public LiteDatabase db_import;
	public LiteDatabase db_tag;
	
	public ILiteCollection<Komi64Info> col_komi64;
	public ILiteCollection<ImportInfo> col_import_info;
	public ILiteCollection<TagInfo> col_tag_info;
	
	public Dictionary<string, Komi64Info> dict_komi64 = new Dictionary<string, Komi64Info>();
	public Dictionary<string, ImportInfo> dict_import_info = new Dictionary<string, ImportInfo>();
	public Dictionary<string, ImportGroup> dict_import_group = new Dictionary<string, ImportGroup>();
	//public Dictionary<string, TagInfo> dict_tag_info = new Dictionary<string, TagInfo>();
	
	public HashSet<string> set_tags = new HashSet<string>();
	
	public Label time_display;
	
	public override void _Ready() { time_display = (Label)GetNode("/root/main/Label2"); }
	
	public int Create() {
		try {
			if (use_journal) {
				db_komi64 = new LiteDatabase(metadata_path + "komi64_info.db");
				BsonMapper.Global.Entity<Komi64Info>().Id(x => x.komi64);		
				col_komi64 = db_komi64.GetCollection<Komi64Info>("komihashes");
				//col_komi64.EnsureIndex((Komi64Info x) => x.komi64, true); // probably not needed since they are _Id
				//col_komi64.EnsureIndex(x => x.tags);
				//col_komi64.EnsureIndex("tags_index", "$.tags[*]");
				col_komi64.EnsureIndex("tags_index", "$.tags[*]", false);
				
				db_import = new LiteDatabase(metadata_path + "import_info.db");
				BsonMapper.Global.Entity<ImportInfo>().Id(x => x.import_id);
				BsonMapper.Global.Entity<ImportGroup>().Id(x => x.komi64);
				col_import_info = db_import.GetCollection<ImportInfo>("import_info");
				//col_import_list = db_import.GetCollection<ImportList>("import_list");
				
				db_tag = new LiteDatabase(metadata_path + "tag_info.db");
				BsonMapper.Global.Entity<TagInfo>().Id(x => x.tag);
				col_tag_info = db_tag.GetCollection<TagInfo>("tags");
			}
			return 0;
		}
		catch (Exception ex) { GD.Print("Database::Create() : ", ex); return 1; }
	}
	public void Destroy() { 
		db_komi64.Dispose(); 
		db_import.Dispose();
		db_tag.Dispose();
	}
	public void CheckpointKomi64() { db_komi64.Checkpoint(); }
	public void CheckpointImport() { db_import.Checkpoint(); }
	public void CheckpointTag() { db_tag.Checkpoint(); }
	
/*=========================================================================================
									   IMPORT INFO
=========================================================================================*/	
	/* loads everything from the "import_info" collection into dict_import_info */
	public int LoadImportInfoFromDatabase() {
		try {
			var imports = col_import_info.FindAll();
			foreach (ImportInfo import in imports) {
				if (import.import_name == null) import.import_name = ""; // prevents a crash caused by the database storing "" as null
				dict_import_info[import.import_id] = import;
			} return ErrorCodes.OK;
		} catch (Exception ex) { GD.Print("Database::LoadImportInfoFromDatabase() : ", ex); return ErrorCodes.ERROR; }
	}
	
	/* gets the ImportInfos from dict_import_info; sorts them, returns the import_ids in sorted order */
	public string[] GetImportIDsFromDict(int sort_by = SortBy.FilePath) { 
		var list = new List<ImportInfo>();
		foreach (string iid in dict_import_info.Keys.ToArray())
			list.Add(dict_import_info[iid]);
		// probably a better way to do this
		var list2 = list.OrderBy(x => x.import_base_folder);
		var list3 = new List<string>();
		foreach (ImportInfo ii in list2) list3.Add(ii.import_id);
		return list3.ToArray();
	}
	
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
			
			GD.Print("Querying...");
			var now = DateTime.Now;
			
			bool random = sort_by == SortBy.Random;
			
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
			
			GD.Print("IG Query finished, took ", (DateTime.Now-now).Milliseconds, " ms\n");
			
			last_query_count = 0;
			foreach (ImportGroup import in imports) {
				dict_import_group[import.komi64] = import;
				list_komi64.Add(import.komi64);
				last_query_count++;
			} 
			return list_komi64.ToArray();	
		} 
		catch (Exception ex) { GD.Print("Database::GetImportGroupRange() : ", ex); return new string[0]; }
	}
	public string GetFileSizeFromHash(string komi64) { return dict_import_group.ContainsKey(komi64) ? dict_import_group[komi64].file_size.ToString() : ""; }
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
	
	public string GetFileSizeFromKomi(string komi64) { return dict_komi64.ContainsKey(komi64) ? dict_komi64[komi64].file_size.ToString() : ""; }
	
	public int InsertKomi64Info(string komi64_n, bool filter_n, string[] paths_n, string[] tags_n, long size_n, long utc_creation_n) {
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
				foreach (string tag in tags_n) {
					if (!temp.tags.Contains(tag)) {
						temp.tags.Add(tag);
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
					file_size = size_n,
					file_creation_utc = utc_creation_n,
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
	public void AddTagToKomi(string komi64, string tag) {
		try {
			var tmp = col_komi64.FindById(komi64);
			if (tmp == null) return;
			if (tmp.tags == null) tmp.tags = new HashSet<string>();
			tmp.tags.Add(tag);
			col_komi64.Update(tmp);
		} catch (Exception ex) { GD.Print("Database::AddTagToKomi() : ", ex); return; }
	}

/*=========================================================================================
								  		  TAG
=========================================================================================*/	
	//public bool CheckDatabaseHasTag(string tag) { return  }
	
	public void LoadTagsFromDatabase() {
		try {
			var tags = col_tag_info.FindAll();
			foreach (TagInfo tag in tags) set_tags.Add(tag.tag);
		} catch (Exception ex) { GD.Print("Database::LoadTagsFromDatabase() : ", ex); return; }
	}
	public string[] GetHashesFromTag(string tag) { 
		try {
			var tmp = col_tag_info.FindById(tag);
			if (tmp != null) return tmp.hashes.ToArray();
			return new string[0];
		} catch (Exception ex) { GD.Print("Database::GetHashesFromTag() : ", ex); return new string[0]; }
	}
	public void CreateTag(string tag_n, string[] hashes_n) {
		try {
			if (set_tags.Contains(tag_n)) {
				var tmp = col_tag_info.FindById(tag_n);
				foreach (string hash in hashes_n)
					tmp.hashes.Add(hash);
				col_tag_info.Update(tmp);
			} else {
				var tmp = new TagInfo {
					tag = tag_n,
					hashes = new HashSet<string>(hashes_n)
				};
				set_tags.Add(tag_n);
				col_tag_info.Insert(tmp);
			}
		} catch (Exception ex) { GD.Print("Database::CreateTag() : ", ex); return; }
	}
	public void AddHashToTag(string tag, string hash) {
		try {
			if (!set_tags.Contains(tag)) CreateTag(tag, new string[]{hash});
			else {
				var tmp = col_tag_info.FindById(tag);
				tmp.hashes.Add(hash);
				set_tags.Add(tag);
				col_tag_info.Update(tmp);
			}
		} catch (Exception ex) { GD.Print("Database::AddHashToTag() : ", ex); return; }
	}
	
	// probably possible to use same function for all 4 checks (ContainsTags()) ; need to step through boolean logic to confirm
	private bool ContainsAllTags(HashSet<string> tag_list, string[] check_tags) { foreach (string tag in check_tags) if (!tag_list.Contains(tag)) return false; return true; }
	private bool ContainsOneTag(HashSet<string> tag_list, string[] check_tags) { foreach (string tag in check_tags) if (tag_list.Contains(tag)) return true; return false; }
//	
	public string GetRandomString(int length) {
		var rand = new Random();
		string s = "";
		char letter;
		int char_value;
		for (int i = 0; i < length; i++) {
			char_value = rand.Next(0, 26);
			letter = Convert.ToChar(char_value+65);
			s += letter;
		}
		return s;
	}
	
	//public void LoadRangeKomi64FromTags(int start_index, int count, string[] tags_have_all, string[] tags_have_one, string[] tags_have_none, int sort_by=SortBy.FileHash, bool ascend=false) {
	public string[] LoadRangeKomi64FromTags(int start_index, int count, string[] tags_have_all, string[] tags_have_one, string[] tags_have_none, int sort_by=SortBy.FileHash, bool ascend=false) {
		try {
			// may need to be moved elsewhere / only done if komihashes != null
			dict_komi64.Clear();
			last_query_count = 0;
			var list = new List<string>();
			
			var komihashes = GetKomi64RangeFromTags(start_index, count, tags_have_all, tags_have_one, tags_have_none, sort_by, ascend);
			if (komihashes != null)
				foreach (Komi64Info khinfo in komihashes)
				{
					dict_komi64[khinfo.komi64] = khinfo;
					list.Add(khinfo.komi64);
					last_query_count++;
					//GD.Print(khinfo.komi64);
				}
			return list.ToArray();
		} catch (Exception ex) { GD.Print("Database::LoadRangeKomi64FromTags() : ", ex); return new string[0]; } //null; }
	}
	
	//private IEnumerable<Komi64Info> GetKomi64RangeFromTags(int start_index, int count, string[] tags_all, string[] tags_any, string[] tags_none, int sort_by=SortBy.FileHash, bool ascend=false) {	
	private List<Komi64Info> GetKomi64RangeFromTags(int start_index, int count, string[] tags_all, string[] tags_any, string[] tags_none, int sort_by=SortBy.FileHash, bool ascend=false) {				
		try {
			GD.Print("Querying...");
			var now = DateTime.Now;
			string column_name = "komi64";
			bool random = false;
			
			if (sort_by == SortBy.FileSize) column_name = "file_size";
			else if (sort_by == SortBy.FileCreationUtc) column_name = "file_creation_utc";
			else if (sort_by == SortBy.Random) random = true;

			// would like to add support for sorting by file paths; but any image could have any number of paths or filenames and even just choosing one would be difficult (syntax-wise)
			// need to consider either removing file_paths from the sort_by dropdown while ALL is selected, or have 2 dropdowns and toggle their visibility depending on whether ALL is selected 
			// need to add support for a global blacklist (tags/hashes in this case)
			
			var rng = new Random();
			
			if (tags_all.Length == 0 && tags_any.Length == 0 && tags_none.Length == 0)
				// NO TAGS
				return col_komi64.Find(Query.All())
					.OrderBy(x => (random) ? rng.Next() : x.GetType().GetProperty(column_name).GetValue(x, null), ascend)
					.Skip(start_index).Take(count).ToList();
			
			var query = col_komi64.Query();
			if (tags_all.Length == 0) {
				// NONE
				if (tags_any.Length == 0) {
					//query = query.Where(x => x.tags.Count > 0); // no speed improvement, need to check if adding a default tag and checking for it improves speed
					foreach (string tag in tags_none) query = query.Where(x => !x.tags.Contains(tag));
				}
				else {
					// ANY
					if (tags_none.Length == 0) query = query.Where("$.tags ANY IN @0", BsonMapper.Global.Serialize(tags_any));
					// ANY + NONE
					else {
						//var predicate = PredicateBuilder.False<Komi64Info>();
						//foreach (string tag in tags_any) predicate = predicate.Or(x => x.tags.Contains(tag));
						//query = query.Where(predicate);
						query = query.Where("$.tags ANY IN @0", BsonMapper.Global.Serialize(tags_any)); // does not improve speed when compared to predicate builder
						foreach (string tag in tags_none) query = query.Where(x => !x.tags.Contains(tag));
					}
				}
			} else {
				if (tags_any.Length == 0) {
					// ALL
					if (tags_none.Length == 0) foreach (string tag in tags_all) query = query.Where(x => x.tags.Contains(tag));
					// ALL + NONE
					else {
						foreach (string tag in tags_all) query = query.Where(x => x.tags.Contains(tag));
						foreach (string tag in tags_none) query = query.Where(x => !x.tags.Contains(tag));
					}
				} else {
					// ALL + ANY
					if (tags_none.Length == 0) {
						foreach (string tag in tags_all) query = query.Where(x => x.tags.Contains(tag));
						query = query.Where("$.tags ANY IN @0", BsonMapper.Global.Serialize(tags_any));
//						var predicate = PredicateBuilder.False<Komi64Info>();
//						foreach (string tag in tags_any) predicate = predicate.Or(x => x.tags.Contains(tag));
//						query = query.Where(predicate);
					} else {
					// ALL + ANY + NONE
						foreach (string tag in tags_all) query = query.Where(x => x.tags.Contains(tag));
						query = query.Where("$.tags ANY IN @0", BsonMapper.Global.Serialize(tags_any));
//						var predicate = PredicateBuilder.False<Komi64Info>();
//						foreach (string tag in tags_any) predicate = predicate.Or(x => x.tags.Contains(tag));
//						query = query.Where(predicate);
						foreach (string tag in tags_none) query = query.Where(x => !x.tags.Contains(tag));
					}					
				}
			}
			
			// currently random only works when viewing all images
			query = (ascend) ? query.OrderBy(column_name) : query.OrderByDescending(column_name);
				
			return query.Skip(start_index).Limit(count).ToList();
		} catch (Exception ex) { GD.Print("Database::GetKomi64RangeFromTags() : ", ex); return null; }
	}
	
	private int GetQueryCountFromTags(string[] tags_all, string[] tags_any, string[] tags_none) {
		try {
			var sw = new Stopwatch();
			int count = 0;
			string time = "";
			
			sw.Start();
			if (tags_all.Length == 0) {
				if (tags_any.Length == 0) {
					// NO TAGS
					if (tags_none.Length == 0) count = col_komi64.Count();
					// NONE
					else {
						var query = col_komi64.Query();
						foreach (string tag in tags_none) query = query.Where(x => !x.tags.Contains(tag));
						count = query.Count();
					}
				} else { 
					// ANY
					if (tags_none.Length == 0) count = col_komi64.Query().Where("$.tags ANY IN @0", BsonMapper.Global.Serialize(tags_any)).Count();
					// ANY + NONE
					else {
						var query = col_komi64.Query();
						var predicate = PredicateBuilder.False<Komi64Info>();
						foreach (string tag in tags_any) predicate = predicate.Or(x => x.tags.Contains(tag));
						query = query.Where(predicate);
						foreach (string tag in tags_none) query = query.Where(x => !x.tags.Contains(tag));
						count = query.Count();
					}
				}
			} else {
				if (tags_any.Length == 0) {
					// ALL
					if (tags_none.Length == 0) {
						var query = col_komi64.Query();
						foreach (string tag in tags_all) query = query.Where(x => x.tags.Contains(tag));
						count = query.Count();
					}
					// ALL + NONE
					else {
						var query = col_komi64.Query();
						foreach (string tag in tags_all) query = query.Where(x => x.tags.Contains(tag));
						foreach (string tag in tags_none) query = query.Where(x => !x.tags.Contains(tag));
						count = query.Count();
					}
				} else {
					// ALL + ANY
					if (tags_none.Length == 0) {
						var query = col_komi64.Query();
						foreach (string tag in tags_all) query = query.Where(x => x.tags.Contains(tag));
						var predicate = PredicateBuilder.False<Komi64Info>();
						foreach (string tag in tags_any) predicate = predicate.Or(x => x.tags.Contains(tag));
						query = query.Where(predicate);
						count = query.Count();
					}
					// ALL + ANY + NONE
					else {
						var query = col_komi64.Query();
						foreach (string tag in tags_all) query = query.Where(x => x.tags.Contains(tag));
						var predicate = PredicateBuilder.False<Komi64Info>();
						foreach (string tag in tags_any) predicate = predicate.Or(x => x.tags.Contains(tag));
						query = query.Where(predicate);
						foreach (string tag in tags_none) query = query.Where(x => !x.tags.Contains(tag));
						count = query.Count();
					}
				}
			}
			sw.Stop();
			
			time += "counted: " + count.ToString() + " images\ntook: " + sw.Elapsed.ToString(@"m\:ss\.fff") + "\n";
			time_display.Text = time;
			
			return count;
		} catch (Exception ex) { GD.Print("Database::GetQueryCountFromTags() : ", ex); return -1; }
	}
	
	
}
