package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class MatchTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "MatchTest", "true", "Matched");
        expectWrite( "MatchTest", "false", "Unmatched");
        expectWrite( "MatchTest", "group", "page.html");
    }
}