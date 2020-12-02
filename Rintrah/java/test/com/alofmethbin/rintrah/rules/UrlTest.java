package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class UrlTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "UrlTest", "test", "Peter's Pages");
    }
}