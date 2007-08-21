/**
 * Copyright (c) 2005 - 2006
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.eclim.util;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import java.net.URL;
import java.net.URLDecoder;

import java.util.ArrayList;
import java.util.List;

import java.util.regex.Pattern;

import javax.xml.parsers.SAXParser;
import javax.xml.parsers.SAXParserFactory;

import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathExpression;
import javax.xml.xpath.XPathFactory;

import org.apache.commons.lang.SystemUtils;

import org.apache.commons.vfs.FileObject;
import org.apache.commons.vfs.FileSystemManager;
import org.apache.commons.vfs.VFS;

import org.eclim.Services;

import org.eclim.command.Error;

import org.eclim.util.file.FileUtils;

import org.w3c.dom.Element;

import org.xml.sax.Attributes;
import org.xml.sax.InputSource;
import org.xml.sax.Locator;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;

import org.xml.sax.helpers.DefaultHandler;

/**
 * Some xml utility methods.
 *
 * @author Eric Van Dewoestine (ervandew@yahoo.com)
 * @version $Revision$
 */
public class XmlUtils
{
  private static final Pattern WIN_BUG = Pattern.compile("^/[a-zA-Z]:/.*");

  private static XPath XPATH;

  /**
   * Create an XPathExpression from the supplied xpath string.
   *
   * @param xpath The xpath string.
   * @return An XPathExpression.
   */
  public static XPathExpression createXPathExpression (String xpath)
    throws Exception
  {
    if(XPATH == null){
      XPATH = XPathFactory.newInstance().newXPath();
    }
    return XPATH.compile(xpath);
  }

  /**
   * Validate the supplied xml file.
   *
   * @param _project The project name.
   * @param _filename The file path to the xml file.
   * @return A possibly empty array of errors.
   */
  public static List<Error> validateXml (String _project, String _filename)
    throws Exception
  {
    return validateXml(_project, _filename, false, null);
  }

  /**
   * Validate the supplied xml file.
   *
   * @param _project The project name.
   * @param _filename The file path to the xml file.
   * @param _schema True to use schema validation relying on the
   * xsi:schemaLocation attribute of the document.
   * @return A possibly empty array of errors.
   */
  public static List<Error> validateXml (
      String _project, String _filename, boolean _schema)
    throws Exception
  {
    return validateXml(_project, _filename, _schema, null);
  }

  /**
   * Validate the supplied xml file.
   *
   * @param _project The project name.
   * @param _filename The file path to the xml file.
   * @param _schema True to use schema validation relying on the
   * xsi:schemaLocation attribute of the document.
   * @param _handler The content handler to use while parsing the file.
   * @return A possibly empty list of errors.
   */
  public static List<Error> validateXml (
      String _project,
      String _filename,
      boolean _schema,
      DefaultHandler _handler)
    throws Exception
  {
    SAXParserFactory factory = SAXParserFactory.newInstance();
    factory.setNamespaceAware(true);
    factory.setValidating(true);
    if(_schema){
      factory.setFeature("http://apache.org/xml/features/validation/schema", true);
      factory.setFeature(
          "http://apache.org/xml/features/validation/schema-full-checking", true);
    }

    SAXParser parser = factory.newSAXParser();

    String filename = FileUtils.concat(
        ProjectUtils.getPath(_project), _filename);

    ErrorAggregator errorHandler = new ErrorAggregator();
    EntityResolver entityResolver = new EntityResolver(
        FileUtils.getFullPath(filename));
    try{
      parser.parse(filename, getHandler(_handler, errorHandler, entityResolver));
    }catch(SAXParseException spe){
      ArrayList<Error> errors = new ArrayList<Error>();
      errors.add(
        new Error(
            spe.getMessage(),
            filename,
            spe.getLineNumber(),
            spe.getColumnNumber(),
            false)
        );
      return errors;
    }

    return errorHandler.getErrors();
  }

  /**
   * Validate the supplied xml file against the specified xsd.
   *
   * @param _project The project name.
   * @param _filename The file path to the xml file.
   * @param _schema The file path to the xsd.
   * @return A possibly empty array of errors.
   */
  public static List<Error> validateXml (String _project, String _filename, String _schema)
    throws Exception
  {
    SAXParserFactory factory = SAXParserFactory.newInstance();
    factory.setNamespaceAware(true);
    factory.setValidating(true);
    factory.setFeature("http://apache.org/xml/features/validation/schema", true);
    factory.setFeature(
        "http://apache.org/xml/features/validation/schema-full-checking", true);

    SAXParser parser = factory.newSAXParser();
    parser.setProperty(
        "http://java.sun.com/xml/jaxp/properties/schemaLanguage",
        "http://www.w3.org/2001/XMLSchema");
    if(!_schema.startsWith("file:")){
      _schema = "file://" + _schema;
    }
    parser.setProperty(
        "http://java.sun.com/xml/jaxp/properties/schemaSource", _schema);
    parser.setProperty(
        "http://apache.org/xml/properties/schema/external-noNamespaceSchemaLocation",
        _schema.replace('\\', '/'));

    ErrorAggregator errorHandler = new ErrorAggregator();
    EntityResolver entityResolver = new EntityResolver(
        FileUtils.getFullPath(_filename));
    try{
      parser.parse(_filename, getHandler(null, errorHandler, entityResolver));
    }catch(SAXParseException spe){
      ArrayList<Error> errors = new ArrayList<Error>();
      errors.add(
        new Error(
            spe.getMessage(),
            _filename,
            spe.getLineNumber(),
            spe.getColumnNumber(),
            false)
        );
      return errors;
    }

    return errorHandler.getErrors();
  }

  /**
   * Gets the value of a named child element.
   *
   * @param element The parent element.
   * @param name The name of the child element to retrieve the value from.
   * @return The text value of the child element.
   */
  public static String getElementValue (Element element, String name)
  {
    return ((Element)element.getElementsByTagName(name).item(0))
      .getFirstChild().getNodeValue();
  }

  /**
   * Gets an aggregate handler which delegates accordingly to the supplied
   * handlers.
   *
   * @param _handler Main DefaultHandler to delegate to (may be null).
   * @param _errorHandler DefaultHandler to delegate errors to (may be null).
   * @param _entityResolver EntityResolver to delegate to (may be null).
   * @return
   */
  private static DefaultHandler getHandler (
      DefaultHandler _handler,
      DefaultHandler _errorHandler,
      EntityResolver _entityResolver)
  {
    DefaultHandler handler = _handler != null ? _handler : new DefaultHandler();
    return new AggregateHandler(handler, _errorHandler, _entityResolver);
  }

  /**
   * Aggregate DefaultHandler which delegates to other handlers.
   */
  private static class AggregateHandler
    extends DefaultHandler
  {
    private DefaultHandler handler;
    private DefaultHandler errorHandler;
    private org.xml.sax.EntityResolver entityResolver;

    /**
     * Constructs a new instance.
     *
     * @param handler The handler for this instance.
     * @param errorHandler The errorHandler for this instance.
     * @param entityResolver The entityResolver for this instance.
     */
    public AggregateHandler (
        DefaultHandler handler,
        DefaultHandler errorHandler,
        EntityResolver entityResolver)
    {
      this.handler = handler;
      this.errorHandler = errorHandler != null ? errorHandler : handler;
      this.entityResolver = entityResolver != null ? entityResolver : handler;
    }

    /**
     * @see DefaultHandler#resolveEntity(String,String)
     */
    public InputSource resolveEntity (String publicId, String systemId)
      throws IOException, SAXException
    {
      return entityResolver.resolveEntity(publicId, systemId);
    }

    /**
     * @see DefaultHandler#notationDecl(String,String,String)
     */
    public void notationDecl (String name, String publicId, String systemId)
      throws SAXException
    {
      handler.notationDecl(name, publicId, systemId);
    }

    /**
     * @see DefaultHandler#unparsedEntityDecl(String,String,String,String)
     */
    public void unparsedEntityDecl (
        String name, String publicId, String systemId, String notationName)
      throws SAXException
    {
      handler.unparsedEntityDecl(name, publicId, systemId, notationName);
    }

    /**
     * @see DefaultHandler#setDocumentLocator(Locator)
     */
    public void setDocumentLocator (Locator locator)
    {
      handler.setDocumentLocator(locator);
    }

    /**
     * @see DefaultHandler#startDocument()
     */
    public void startDocument ()
      throws SAXException
    {
      handler.startDocument();
    }

    /**
     * @see DefaultHandler#endDocument()
     */
    public void endDocument ()
      throws SAXException
    {
      handler.endDocument();
    }

    /**
     * @see DefaultHandler#startPrefixMapping(String,String)
     */
    public void startPrefixMapping (String prefix, String uri)
      throws SAXException
    {
      handler.startPrefixMapping(prefix, uri);
    }

    /**
     * @see DefaultHandler#endPrefixMapping(String)
     */
    public void endPrefixMapping (String prefix)
      throws SAXException
    {
      handler.endPrefixMapping(prefix);
    }

    /**
     * @see DefaultHandler#startElement(String,String,String,Attributes)
     */
    public void startElement (
        String uri, String localName, String qName, Attributes attributes)
      throws SAXException
    {
      handler.startElement(uri, localName, qName, attributes);
    }

    /**
     * @see DefaultHandler#endElement(String,String,String)
     */
    public void endElement (String uri, String localName, String qName)
      throws SAXException
    {
      handler.endElement(uri, localName, qName);
    }

    /**
     * @see DefaultHandler#characters(char[],int,int)
     */
    public void characters (char[] ch, int start, int length)
      throws SAXException
    {
      handler.characters(ch, start, length);
    }

    /**
     * @see DefaultHandler#ignorableWhitespace(char[],int,int)
     */
    public void ignorableWhitespace (char[] ch, int start, int length)
      throws SAXException
    {
      handler.ignorableWhitespace(ch, start, length);
    }

    /**
     * @see DefaultHandler#processingInstruction(String,String)
     */
    public void processingInstruction (String target, String data)
      throws SAXException
    {
      handler.processingInstruction(target, data);
    }

    /**
     * @see DefaultHandler#skippedEntity(String)
     */
    public void skippedEntity (String name)
      throws SAXException
    {
      handler.skippedEntity(name);
    }

    /**
     * @see DefaultHandler#warning(SAXParseException)
     */
    public void warning (SAXParseException e)
      throws SAXException
    {
      errorHandler.warning(e);
    }

    /**
     * @see DefaultHandler#error(SAXParseException)
     */
    public void error (SAXParseException e)
      throws SAXException
    {
      errorHandler.error(e);
    }

    /**
     * @see DefaultHandler#fatalError(SAXParseException)
     */
    public void fatalError (SAXParseException e)
      throws SAXException
    {
      errorHandler.fatalError(e);
    }
  }

  /**
   * Handler for collecting errors durring parsing and validation of a xml
   * file.
   */
  private static class ErrorAggregator
    extends DefaultHandler
  {
    private ArrayList<Error> errors = new ArrayList<Error>();

    /**
     * {@inheritDoc}
     */
    public void warning (SAXParseException _ex)
      throws SAXException
    {
      addError(_ex, true);
    }

    /**
     * {@inheritDoc}
     */
    public void error (SAXParseException _ex)
      throws SAXException
    {
      addError(_ex, false);
    }

    /**
     * {@inheritDoc}
     */
    public void fatalError (SAXParseException _ex)
      throws SAXException
    {
      addError(_ex, false);
    }

    /**
     * Adds the supplied SAXException as an Error.
     *
     * @param _ex The SAXException.
     */
    private void addError (SAXParseException _ex, boolean _warning)
    {
      String location = _ex.getSystemId();
      if(location != null && location.startsWith("file://")){
        location = location.substring("file://".length());
      }
      // bug where window paths start with /C:/...
      if(location != null && WIN_BUG.matcher(location).matches()){
        location = location.substring(1);
      }
      try{
        errors.add(new Error(
              _ex.getMessage(),
              URLDecoder.decode(location, "utf-8"),
              _ex.getLineNumber(),
              _ex.getColumnNumber(),
              _warning));
      }catch(Exception e){
        throw new RuntimeException(e);
      }
    }

    /**
     * Gets the possibly empty array of errors.
     *
     * @return Array of Error.
     */
    public List<Error> getErrors ()
    {
      return errors;
    }
  }

  /**
   * EntityResolver extension.
   */
  private static class EntityResolver
    implements org.xml.sax.EntityResolver
  {
    private static String TEMP_PREFIX =
      "file://" + SystemUtils.JAVA_IO_TMPDIR.replace('\\', '/');
    static{
      if(TEMP_PREFIX.endsWith("\\") || TEMP_PREFIX.endsWith("/")){
        TEMP_PREFIX = TEMP_PREFIX.substring(0, TEMP_PREFIX.length() - 1);
      }
    }

    private String path;
    private String lastPath;

    /**
     * Constructs a new instance.
     *
     * @param _path The path for all relative entities to be relative to.
     */
    public EntityResolver (String _path)
    {
      path = _path;
    }

    /**
     * {@inheritDoc}
     */
    public InputSource resolveEntity (String _publicId, String _systemId)
      throws SAXException, IOException
    {
      String location = _systemId;
      // rolling the dice to fix windows issue where parser, or something, is
      // turning C:/... into C/.  This would cause problems if someone acutally
      // has a single letter directory, but that is doubtful.
      location = location.replaceFirst("^file://([a-zA-Z])/", "file://$1:/");

      if(location.startsWith(TEMP_PREFIX)){
        location = location.substring(TEMP_PREFIX.length());
        return resolveEntity(_publicId, lastPath + location);
      }else if(location.startsWith("http://")){
        int index = location.indexOf('/', 8);
        lastPath = location.substring(0, index + 1);
        location = location.substring(index);

        location = TEMP_PREFIX + location;

        FileSystemManager fsManager = VFS.getManager();
        FileObject tempFile = fsManager.resolveFile(location);

        // check if temp file already exists.
        if(!tempFile.exists() || tempFile.getContent().getSize() == 0){
          InputStream in = null;
          OutputStream out = null;
          try{
            if(!tempFile.exists()){
              tempFile.createFile();
            }

            // download and save remote file.
            URL remote = new URL(_systemId);
            in = remote.openStream();
            out = tempFile.getContent().getOutputStream();
            IOUtils.copy(in, out);
          }catch(Exception e){
            IOUtils.closeQuietly(out);
            try{
              tempFile.delete();
            }catch(Exception ignore){
            }

            IOException ex = new IOException(e.getMessage());
            ex.initCause(e);
            throw ex;
          }finally{
            IOUtils.closeQuietly(in);
            IOUtils.closeQuietly(out);
          }
        }

        InputSource source =  new InputSource(
            tempFile.getContent().getInputStream());
        source.setSystemId(location);
        return source;

      }else if(location.startsWith("file:")){
        location = location.substring("file:".length());
        if(location.startsWith("//")){
          location = location.substring(2);
        }
        if(FileUtils.getFullPath(location).equals(
              FileUtils.getPath(location)))
        {
          location = FileUtils.concat(path, location);
        }

        if(!new File(location).exists()){
          StringBuffer resource = new StringBuffer()
            .append("/resources/")
            .append(FileUtils.getExtension(location))
            .append('/')
            .append(FileUtils.getFileName(location))
            .append('.')
            .append(FileUtils.getExtension(location));
          URL url = Services.getResource(resource.toString());
          if(url != null){
            return new InputSource(url.toString());
          }
        }
        return new InputSource(location);
      }

      return new InputSource(_systemId);
    }
  }
}
