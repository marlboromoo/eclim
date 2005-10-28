/**
 * Copyright (c) 2004 - 2005
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
package org.eclim.command.project;

import java.io.IOException;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import org.eclim.client.Options;

import org.eclim.command.AbstractCommand;
import org.eclim.command.CommandLine;

import org.eclim.server.eclipse.EclimPreferences;
import org.eclim.server.eclipse.Option;

import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.ResourcesPlugin;

/**
 * Command to obtain project info.
 *
 * @author Eric Van Dewoestine (ervandew@yahoo.com)
 * @version $Revision$
 */
public class ProjectInfoCommand
  extends AbstractCommand
{
  private static final Log log = LogFactory.getLog(ProjectInfoCommand.class);

  private EclimPreferences eclimPreferences;

  /**
   * {@inheritDoc}
   */
  public Object execute (CommandLine _commandLine)
    throws IOException
  {
    try{
      String name = _commandLine.getValue(Options.NAME_OPTION);
      List results = new ArrayList();

      // list all projects.
      if(name == null){
        IProject[] projects = ResourcesPlugin.getWorkspace().getRoot().getProjects();
        for(int ii = 0; ii < projects.length; ii++){
          if(projects[ii].exists()){
            StringBuffer info = new StringBuffer(projects[ii].getName())
              .append(" - ")
              .append(projects[ii].getRawLocation());
            results.add(info.toString());
          }
        }

      // retrieve project settings.
      }else{
        IProject project = ResourcesPlugin.getWorkspace().getRoot()
          .getProject(name);
        String setting = _commandLine.getValue(Options.SETTING_OPTION);
        Option[] options = eclimPreferences.getOptions(project);

        // only retrieving the requested setting.
        if(setting != null){
          for(int ii = 0; ii < options.length; ii++){
            if(options[ii].getName().equals(setting)){
              results.add(options[ii]);
              break;
            }
          }

        // retrieve all settings.
        }else{
          results.addAll(Arrays.asList(options));
        }
      }
     return filter(_commandLine, results);
    }catch(Throwable t){
      return t;
    }
  }

  /**
   * Set eclimPreferences.
   * <p/>
   * Dependency injection.
   *
   * @param _eclimPreferences the value to set.
   */
  public void setEclimPreferences (EclimPreferences _eclimPreferences)
  {
    this.eclimPreferences = _eclimPreferences;
  }
}
