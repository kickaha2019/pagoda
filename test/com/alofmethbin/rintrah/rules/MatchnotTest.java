package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class MatchnotTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "MatchnotTest", "true", "Matched");
        expectWrite( "MatchnotTest", "false", "Unmatched");
    }
}