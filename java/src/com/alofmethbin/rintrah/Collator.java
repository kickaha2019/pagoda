package com.alofmethbin.rintrah;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

/**
 * Collate results of Scanner with game names in the database
 * 
 * Arguments:
 *   Game data file
 *   Alias data file
 *   Bind data file
 *   Scanner data file
 *   Optionally scan id to collate
 *   Optionally game id to collate against
 */
public class Collator {

    // HTML ornaments
    public static String[] htmlOrnaments = new String[]{"acute", "cedil", "circ", "grave", "ring", "slash", "tilde", "uml"};

    // Explicitly mapped HTML entities
    public static Map<String, String> htmlExplicit = new TreeMap<String, String>();

    static {
        htmlExplicit.put("#039", "'");
        htmlExplicit.put("#8211", "-");
        htmlExplicit.put("#8217", "'");
        htmlExplicit.put("#x26", "and");
        htmlExplicit.put("#x27", "'");
        htmlExplicit.put("acute", "'");
        htmlExplicit.put("aelig", "ae");
        htmlExplicit.put("amp", "and");
        htmlExplicit.put("eth", "d");
        htmlExplicit.put("frac12", "1/2");
        htmlExplicit.put("hellip", "...");
        htmlExplicit.put("ldquo", "\"");
        htmlExplicit.put("lt", "<");
        htmlExplicit.put("ndash", "-");
        htmlExplicit.put("quot", "\"");
        htmlExplicit.put("rdquo", "\"");
        htmlExplicit.put("rt", ">");
        htmlExplicit.put("szlig", "sz");
        htmlExplicit.put("thorn", "th");
    }

    // Explicitly ignored strings in crunch() logic
    public static Set<String> crunchIgnore = new TreeSet<String>();

    static {
        crunchIgnore.add("a");
        crunchIgnore.add("an");
        crunchIgnore.add("and");
        crunchIgnore.add("in");
        crunchIgnore.add("s");
        crunchIgnore.add("the");
        crunchIgnore.add("walkthrough");
    }
    // Explicitly translated strings in crunch() logic
    public static Map<String, String> crunchTranslate = new TreeMap<String, String>();

    static {
        crunchTranslate.put("one", "1");
        crunchTranslate.put("two", "2");
        crunchTranslate.put("three", "3");
        crunchTranslate.put("four", "4");
        crunchTranslate.put("five", "5");
        crunchTranslate.put("six", "6");
        crunchTranslate.put("seven", "7");
        crunchTranslate.put("eight", "8");
        crunchTranslate.put("nine", "9");
        crunchTranslate.put("ten", "10");
        crunchTranslate.put("eleven", "11");
        crunchTranslate.put("twelve", "12");
        crunchTranslate.put("thirteen", "13");
        crunchTranslate.put("fourteen", "14");
        crunchTranslate.put("fifteen", "15");
        crunchTranslate.put("sixteen", "16");
        crunchTranslate.put("seventeen", "17");
        crunchTranslate.put("eighteen", "18");
        crunchTranslate.put("nineteen", "19");
        crunchTranslate.put("twenty", "20");
        crunchTranslate.put("i", "1");
        crunchTranslate.put("ii", "2");
        crunchTranslate.put("iii", "3");
        crunchTranslate.put("iv", "4");
        crunchTranslate.put("v", "5");
        crunchTranslate.put("vi", "6");
        crunchTranslate.put("vii", "7");
        crunchTranslate.put("viii", "8");
        crunchTranslate.put("ix", "9");
        crunchTranslate.put("x", "10");
        crunchTranslate.put("xi", "11");
        crunchTranslate.put("xii", "12");
        crunchTranslate.put("first", "1st");
        crunchTranslate.put("second", "2nd");
        crunchTranslate.put("third", "3rd");
        crunchTranslate.put("fourth", "4th");
        crunchTranslate.put("fifth", "5th");
        crunchTranslate.put("sixth", "6th");
        crunchTranslate.put("seventh", "7th");
        crunchTranslate.put("eighth", "8th");
        crunchTranslate.put("ninth", "9th");
        crunchTranslate.put("tenth", "10th");
        crunchTranslate.put("eleventh", "11th");
        crunchTranslate.put("twelfth", "12th");
        crunchTranslate.put("thirteenth", "13th");
        crunchTranslate.put("fourteenth", "14th");
        crunchTranslate.put("fifteenth", "15th");
        crunchTranslate.put("sixteenth", "16th");
        crunchTranslate.put("seventeenth", "17th");
        crunchTranslate.put("eighteenth", "18th");
        crunchTranslate.put("nineteenth", "19th");
        crunchTranslate.put("twentieth", "20th");
        crunchTranslate.put("&amp;", "and");
        crunchTranslate.put("center", "centre");
        crunchTranslate.put("escape", "esc");
        crunchTranslate.put("versus", "vs");
        crunchTranslate.put("volume", "vol");
    }

    // Class for statistics
/*	class Statistic {
    String site, type;
    int [] count;
    StringBuffer [] ids;
    } */
    // Ranges of values in statistics
    //private static int [] range = new int [] {0, 1, 2, 3, 4, 5, 10};

    /**
     * Run Collator
     * @param args
     */
    public static void main(String[] args) {

        // Find id to collate or -1 for all
        try {
            int gameId = -1;
            if (args.length >= 7) {
                gameId = Integer.parseInt(args[6]);
            }

            // Load the name and ids from the game and alias data
            Collator collator = new Collator();
            collator.loadNames(args[0], false, gameId);
            collator.loadNames(args[1], true, gameId);

            // Load the binds
            collator.loadBinds(args[2]);

            // Open output file
            collator.openOutput(args[4]);

            // Find id to collate or -1 for all
            int collateId = -1;
            if (args.length >= 6) {
                collateId = Integer.parseInt(args[5]);
            }

            // Process the scanned data
            collator.process(args[3], collateId);

            // Close output file
            collator.closeOutput();

            // List binds not matched
            for (String bind: collator.binds.keySet()) {
                if (! collator.bindsMatched.contains( bind)) {
                    errors ++;
                    System.err.println( "**** Unmatched bind: " + bind);
                }
            }

            if (errors > 0) {
                System.exit(1);
            }
            
        } catch (Throwable t) {
            t.printStackTrace();
            System.exit(1);
        }
    }

    // Constructor
    private Collator() {
    }

    // Close output file
    private void closeOutput() throws Exception {
        output.close();
    }

    /**
     * Crunch name to collection of words
     */
    public static void crunch(String ref, String name, Collection<String> words) {
        // Weird character found
        String weird = null;
        String origName = name;

        // Convert HTML entities to Latin letters
        StringBuffer b = new StringBuffer();
        for (int i = 0; i < name.length();) {
            char ch = name.charAt(i);

            // Not an entity next
            if (ch != '&') {
                b.append(ch);
                i++;
                continue;
            }

            // & without trailing ;
            int pos = name.indexOf(';', i);
            if (pos < 0) {
                b.append(ch);
                i++;
                continue;
            }

            // Entity
            String entity = name.substring(i + 1, pos).toLowerCase();
            i = pos + 1;

            // Ornamented letter?
            for (int j = 0; j < htmlOrnaments.length; j++) {
                if (entity.endsWith(htmlOrnaments[j])) {
                    b.append(entity.charAt(0));
                    entity = null;
                    break;
                }
            }

            // Explicitly mapped?
            if ((entity != null) && htmlExplicit.containsKey(entity)) {
                b.append(htmlExplicit.get(entity));
                entity = null;
            }

            // Numeric character code?  Just replace by space for now
            if ((entity != null) && entity.startsWith( "#")) {
                b.append( " ");
                entity = null;
            }

            // Some weirdo character then
            if (entity != null) {
                b.append("!");
                weird = entity;
            }
        }

        name = b.toString();

        // Split name up into words ignoring odd characters
        b.setLength(0);
        for (int i = 0; i < name.length(); i++) {
            char ch = name.charAt(i);
            if ((ch == '\'') || (ch == ',')) {
                continue;
            }
            if (Character.isLetterOrDigit(ch)) {
                b.append(ch);
            } else {
                if ((Character.getNumericValue(ch) > 0xFF) || Character.isISOControl(ch)) {
                    weird = "" + ch;
                }
                crunchWord(b, words);
            }
        }

        crunchWord(b, words);

        // Report weird characters found
        if (weird != null) {
            errors ++;
            System.err.println(ref + ": problem in name [" + origName + "] at [" + weird + "]");
        }
    }

    // Crunch helper
    private static void crunchWord(StringBuffer b, Collection<String> words) {
        if (b.length() > 0) {
            String word = b.toString().toLowerCase();
            b.setLength(0);

            if (crunchIgnore.contains(word)) {
                return;
            }

            if ((words.size() > 0) || (! (word.equalsIgnoreCase( "I") || word.equalsIgnoreCase( "X")))) {
                if (crunchTranslate.containsKey(word)) {
                    word = crunchTranslate.get(word);
                }
            }

            if (word.endsWith("s") && (word.length() > 3)) {
                word = word.substring(0, word.length() - 1);
            }

            words.add(word.intern());
        }
    }

    // Dump statistics
/*	private void dumpStatistics( String filename) throws Exception
    {
    FileWriter writer = new FileWriter( filename);
    writer.write( "<HTML><HEAD></HEAD><BODY>\n");
    writer.write( "<TABLE BORDER=1>\n");
    writer.write( "<TR><TH>Site</TH><TH>Type</TH>");
    for (int j = 0; j < range.length; j++) {
    writer.write( "<TH>");
    if (j == (range.length - 1)) {
    writer.write( range[j] + "-");}
    else if ((range[j] + 1) < range[j+1]) {
    writer.write( range[j] + "-" + (range[j+1] - 1));}
    else {
    writer.write( Integer.toString( range[j]));
    }
    writer.write( "</TH>");
    }
    writer.write( "</TR>\n");
    for (Iterator i = statistics.iterator(); i.hasNext();) {
    Statistic s = (Statistic) i.next();
    writer.write( "<TR><TD>" + s.site + "</TD>");
    writer.write( "<TD>" + s.type + "</TD>");
    for (int j = 0; j < range.length; j++) {
    writer.write( "<TD TITLE=\"" + s.ids[j].toString() + "\">");
    writer.write( s.count[j] + "</TD>");
    }
    writer.write( "</TR>\n");
    }
    writer.write( "</TABLE>\n");
    writer.write( "</BODY></HTML>\n");
    writer.close();
    } */
    // Get ordinal (1 2 3 ... 99) from set of strings
    private String getOrdinal(Collection<String> nameWords2) {
        String found = null;

        for (Iterator<String> i = nameWords2.iterator(); i.hasNext();) {
            try {
                int ord = Integer.parseInt(i.next());
                if ((ord >= 1) && (ord <= 99)) {
                    if (found != null) {
                        return null;
                    }
                    found = Integer.toString(ord);
                }
            } catch (Exception ex) {
            }
        }

        return found;
    }

    // Load url / id binds from database file
    private void loadBinds(String filename) throws Exception {
        BufferedReader reader = new BufferedReader(new FileReader(filename));

        // Get positions of url and id from first line
        String line = reader.readLine();
        String[] parts = Scanner.split(line);
        int idColumn = -1;
        int urlColumn = -1;

        for (int i = 0; i < parts.length; i++) {
            if ("id".equals(parts[i])) {
                idColumn = i;
            }
            if ("url".equals(parts[i])) {
                urlColumn = i;
            }
        }

        if ((idColumn < 0) || (urlColumn < 0)) {
            throw new Exception("id or url column not found in " + filename);
        }

        // Read through the data
        while ((line = reader.readLine()) != null) {
            if ((line = line.trim()).length() < 1) {
                continue;
            }
            parts = Scanner.split(line);
            int id = Integer.parseInt(parts[idColumn]);
            String url = parts[urlColumn];
            binds.put(url, new Integer(id));
        }

        reader.close();
    }

    // Load id / names from database file
    private void loadNames(String filename, boolean alias, int loadId) throws Exception {
        BufferedReader reader = new BufferedReader(new FileReader(filename));

        // Get positions of id and name etc from first line
        String line = reader.readLine();
        String[] parts = Scanner.split(line);
        int idColumn = -1;
        int nameColumn = -1;
        int yearColumn = -1;
        int groupColumn = -1;

        for (int i = 0; i < parts.length; i++) {
            if ("id".equals(parts[i])) {
                idColumn = i;
            }
            if ("name".equals(parts[i])) {
                nameColumn = i;
            }
            if ("year".equals(parts[i])) {
                yearColumn = i;
            }
            if ("is_group".equals(parts[i])) {
                groupColumn = i;
            }
        }

        if ((idColumn < 0) || (nameColumn < 0)) {
            throw new Exception("id or name column not found in " + filename);
        }

        // Read through the data
        while ((line = reader.readLine()) != null) {
            if ((line = line.trim()).length() < 1) {
                continue;
            }
            parts = Scanner.split(line);
            int id = Integer.parseInt(parts[idColumn]);
            String name = parts[nameColumn];

            // Check for explicit id wanted
            if ((loadId >= 0) && (loadId != id)) {
                continue;
            }

            // Check for group which we won't match against
            if ((groupColumn >= 0) && parts[groupColumn].equals("Y")) {
                continue;
            }
            
            // Add the year if present to the idYear map
            Integer idKey = new Integer(id);
            if ((yearColumn >= 0) && (parts[yearColumn].length() == 4)) {
                idYear.put(idKey, parts[yearColumn]);
            }

            // Add the name to the name / word map
            Set<String> words = new HashSet<String>();
            crunch(filename, name, words);
            nameWords.put(name, words);

            // Add the words to the id / all word map
            Collection<String> allWords = idAllWords.get(idKey);

            if (allWords == null) {
                idAllWords.put(idKey, allWords = new HashSet<String>());
            }

            allWords.addAll(words);

            // Add year if known to the words
            if (idYear.containsKey(idKey)) {
                allWords.add(idYear.get(idKey));
            }

            // Add the id / name to the name id maps
            nameId.put(name, idKey);
            if (!alias) {
                idName.put(idKey, words);
            }

            // If not an alias maintain frequencies for the words
            if (!alias) {
                for (Iterator<String> wi = words.iterator(); wi.hasNext();) {
                    String w = wi.next();
                    Integer count = wordFreqs.get(w);
                    if (count != null) {
                        wordFreqs.put(w, new Integer(count.intValue() + 1));
                    } else {
                        wordFreqs.put(w, new Integer(1));
                    }
                }
            }
        }

        reader.close();
    }

    // Open output file
    private void openOutput(String filename) throws Exception {
        output = new FileWriter(new File(filename));
        output.write("id\tlink\tlength\n");
    }

    // Process scanned data
    private void process(String filename, int collateId) throws Exception {
        BufferedReader reader = new BufferedReader(new FileReader(filename));

        // Get positions of columns from first line
        String line = reader.readLine();
        String[] parts = Scanner.split(line);
        int linkColumn = -1;
        int nameColumn = -1;
        int siteColumn = -1;
        int typeColumn = -1;
        int urlColumn = -1;

        for (int i = 0; i < parts.length; i++) {
            if ("id".equals(parts[i])) {
                linkColumn = i;
            }
            if ("name".equals(parts[i])) {
                nameColumn = i;
            }
            if ("site".equals(parts[i])) {
                siteColumn = i;
            }
            if ("type".equals(parts[i])) {
                typeColumn = i;
            }
            if ("url".equals(parts[i])) {
                urlColumn = i;
            }
        }

        if ((linkColumn < 0) || (nameColumn < 0) || (siteColumn < 0) || (typeColumn < 0) || (urlColumn < 0)) {
            throw new Exception("Expected columns not found in " + filename);
        }

        // Read through the data
        while ((line = reader.readLine()) != null) {
            if ((line = line.trim()).length() < 1) {
                continue;
            }
            parts = Scanner.split(line);
            int link = Integer.parseInt(parts[linkColumn]);
            String name = parts[nameColumn];
            String url = parts[urlColumn];

            // Collate this id?
            if ((collateId >= 0) && (collateId != link)) {
                continue;
            }

            // Crunch &amp; in urls to be just & to match binds
            String url1 = url.replaceAll( "&amp;", "&");
            
            // Explicit bind?
            Integer bind = binds.get(url);
            if (bind == null) {bind = binds.get(url1);}
            
            if (bind != null) {
                bindsMatched.add( url);

                // Bind to a game?
                if (bind.intValue() >= 0) {
                    output.write(bind + "\t" + link + "\t" + 0 + "\n");
                }

                continue;
            }

            // Empty names match nothing
            Set<String> words = new HashSet<String>();
            crunch(filename, name, words);
            if (words.size() == 0) {
                //addStatistic( parts[ siteColumn], parts[ typeColumn], link, 0);
                continue;
            }

            // Find defined game with name which include the scan name
            // but is only such game or the names exactly match
            int matchId = -1, matchOneId = -1, matchAllId = -1;
            boolean exact = false, ambiguous = false, ambiguousOne = false, ambiguousAll = false;
            boolean noOrdinal = (getOrdinal(words) == null);

            for (Iterator<Map.Entry<String, Collection<String>>> i = nameWords.entrySet().iterator(); i.hasNext();) {
                Map.Entry<String, Collection<String>> e = i.next();
                Collection<String> nw = e.getValue();
                Integer id = nameId.get(e.getKey());

                if (nw.containsAll(words)) {
                    if (nw.size() == words.size()) {
                        matchId = id;
                        ambiguous = false;
                        exact = true;
                        break;
                    } else {
                        if ((matchId >= 0) && (matchId != id)) {
                            ambiguous = true;
                        } else {
                            matchId = id;
                        }

                        if (noOrdinal && "1".equalsIgnoreCase( getOrdinal( nw))) {
                            if (matchOneId >= 0) {
                                ambiguousOne = true;
                            } else {
                                matchOneId = id;
                            }
                        }
                    }
                }

                Collection<String> aw = idAllWords.get( id);
                if (aw.containsAll(words)) {
                   if ((matchAllId >= 0) && (matchAllId != id)) {
                        ambiguousAll = true;
                   } else {
                        matchAllId = id;
                   }
                }
            }

            if (ambiguous && (! ambiguousOne) && (matchOneId >= 0)) {
                matchId = matchOneId;
                ambiguous = false;
            }

            if (matchId < 0) {
                matchId = matchAllId;
                ambiguous = ambiguousAll;
            }

            // Write out ranking records
            if ((! ambiguous) && (matchId >= 0)) {
                output.write( matchId + "\t" + link + "\t" + words.size() + "\n");
            }
        }

        reader.close();
    }

    // Map of urls to explicit bind ids
    private Map<String, Integer> binds = new HashMap<String, Integer>();

    // Set of bind urls matched
    private Set<String> bindsMatched = new HashSet<String>();
    
    // Number of errors
    private static int errors = 0;
    
    // Map of id to words in any title or alias for the game
    private Map<Integer, Collection<String>> idAllWords = new HashMap<Integer, Collection<String>>();

    // Map of ids to words of game name
    private Map<Integer, Collection<String>> idName = new HashMap<Integer, Collection<String>>();

    // Map of ids to game year
    private Map<Integer, String> idYear = new HashMap<Integer, String>();

    // Map of name (or alias) to its game id
    private Map<String, Integer> nameId = new HashMap<String, Integer>();

    // Map of names to words in the names
    private Map<String, Collection<String>> nameWords = new HashMap<String, Collection<String>>();

    // Output writer
    private FileWriter output;

    // Statistics
    //private List statistics = new ArrayList();

    // Map of words to their frequencies
    private Map<String, Integer> wordFreqs = new HashMap<String, Integer>();
}
