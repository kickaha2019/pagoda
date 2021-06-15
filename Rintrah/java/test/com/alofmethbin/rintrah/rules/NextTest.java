package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class NextTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "NextTest", "test", "text/html; charset=iso-8859-1");
        expectWrite( "NextTest", "skipText", "A", "FONT");
        expectWrite( "NextTest", "skipScript", "#0000CC");
        expectWrite( "NextTest", "nextH2", "International Plan Statement for the period 1 January 2010 - 31 December 2010");
    }
}
