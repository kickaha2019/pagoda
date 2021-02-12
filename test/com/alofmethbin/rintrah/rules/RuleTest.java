package com.alofmethbin.rintrah.rules;

import static org.junit.Assert.assertEquals;

import java.util.List;

import com.alofmethbin.rintrah.TestScanner;
import org.junit.Ignore;

@Ignore
public class RuleTest {
	
    /**
     * Check that running branch gives expected error
     * @param script Script to use
     * @param branch Branch to run
     * @param line Expected write
     * @throws Exception
     */
    protected void expectError(String script, String branch, String error) throws Exception {
        TestScanner ts = new TestScanner(script);
        ts.execute(branch);
        assertEquals(error, ts.getError());
    }

    /**
     * Check that running branch gives expected write
     * @param branch Branch to run
     * @param line Expected write
     * @throws Exception
     */
    protected void expectWrite(String script, String branch, String... line) throws Exception {
        TestScanner ts = new TestScanner(script);
        List<String[]> lines = ts.execute(branch);
        assertEquals(line.length, lines.size());
        for (int i = 0; i < line.length; i++) {
            assertEquals(1, lines.get(i).length);
            assertEquals( line[i], lines.get(i)[0]);
        }
    }
}
