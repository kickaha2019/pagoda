package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class UrlencodeTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "URLEncodeTest", "test1", "http%3A%2F%2Fwww.alofmethbin.com%2FArticles%2FDiary%2F2014%2FAzura%2Fboarding%2Findex.html");
    }
}