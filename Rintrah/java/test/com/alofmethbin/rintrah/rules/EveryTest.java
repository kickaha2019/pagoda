package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class EveryTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "EveryTest", "test", "browseOptions1:panel.viewnum:viewNumSelect");
        expectWrite( "EveryTest", "badElement", "Broken Sword: The Smoking Mirror");
    }
}
