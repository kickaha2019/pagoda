package com.alofmethbin.rintrah;

import java.io.Reader;

/**
 * Plugin to convert document before parsing HTML
 */
public interface URLPlugin {

    /**
     * Convert document from URL
     * @param reader Reader for document
     * @return Converted document
     */
    String convert( Reader reader) throws Exception;
}
