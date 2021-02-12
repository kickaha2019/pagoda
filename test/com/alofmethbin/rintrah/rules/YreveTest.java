package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class YreveTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "YreveTest", "test", "RevealTrans (Duration=2, Transition=23)");
    }
}
