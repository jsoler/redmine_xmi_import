require 'nokogiri'
require 'nokogiri/xml/reader'
require 'tempfile'

#TODO: mover a modulos
class Basexmi
  attr_accessor :id, :title, :note, :type, :author
end

class RequirementXmi < Basexmi
  attr_accessor :relatedtests
end

class TestCaseXmi < Basexmi
end

class XmiImportController < ApplicationController
  unloadable

  before_filter :authorize_global
  before_filter :find_project


  @@requirements=[]

  def index
  end

  def match
    file = params[:file]
    if !file.nil?
      @original_filename = file.original_filename
      tmpfile = Tempfile.new("redmine_importer")
      tmpfile.binmode
      file.binmode
      if tmpfile
        tmpfile.write(file.read)
        tmpfile.close
        tmpfilename = File.basename(tmpfile.path)
      else
        flash[:error] = "No se ha podido guardar el fichero"
        return
      end
    else
      flash[:error] = "Fichero vacío, por favor cargue un fichero con datos."
      return
    end


    if parse_xmi(tmpfile)

      #TODO: permitir elegirlo antes de importar
      # valores por defecto de los campos
      default_tracker = 'Requisitos'
      default_issue_status = 'Nuevo'
      default_issue_priority='Normal'
      default_author='jsoler'
      default_fixed_version='Requisitos'
      default_category='Requisitos'

      @handle_count = 0
      @update_count = 0
      @skip_count = 0
      @failed_count = 0
      @failed_issues = []
      @affect_projects_issues = Hash.new

      @@requirements.each { |requirement|

        tracker = Tracker.find_by_name(default_tracker)
        status = IssueStatus.find_by_name(default_issue_status)
        priority= IssuePriority.find_by_name(default_issue_priority)
        author_optional = User.find_by_login(default_author)
        author = User.find_by_login(requirement.author)

        #TODO: buscar categoria nombre relacionado con requisitos
        category = IssueCategory.find_by_name(default_category)

        #TODO: buscar versión nombre relacionado con requisitos
        fixed_version = Version.find_by_name_and_project_id(default_fixed_version,@project.id)

        # new issue or find exists one
        issue = Issue.new
        issue.project_id = @project.id
        issue.tracker_id = tracker != nil ? tracker.id : default_tracker
        issue.author_id = author != nil ? author.id : author_optional.id

        @affect_projects_issues.has_key?(@project.name) ?
          @affect_projects_issues[@project.name] += 1 : @affect_projects_issues[@project.name] = 1

        issue.subject = requirement.title || issue.subject
        issue.description =requirement.note || issue.description
        issue.category_id = category != nil ? category.id : nil
        issue.start_date = Date.today || issue.start_date
        issue.fixed_version_id = fixed_version != nil ? fixed_version.id : @project.versions.first.id
        #TODO: asignar campos personaliados: tipo requisito
        requirement_to_stereotype={'RF' => 'Funcional',
                                'RFN' => 'No funcional',
                                'PV' =>'De Interfaz',
                                'AC' => 'Actor',
                                'RA'=>'De Información'}
        issue.custom_field_values.first.update_attribute('value', requirement_to_stereotype[requirement.type])

        if (!issue.save)
          @failed_count += 1
          @failed_issues << requirement
        end


      }

    else
      flash[:error] = "Plugin de importación XMI no soporta la versión del fichero cargado"
    end
  end

private

  def find_project
    @project = Project.find(params[:project_id])
  end

  def parse_xmi(filename)
    #TODO: mover a modulo, separar logica de los diferentes versiones de xmi
    #parseador valido para version XMI xmi.version="1.1"

    reader = Nokogiri::XML::Reader(filename.open)

    current_requirement = nil
    current_testcase = nil
    check_version=true
    # tipos de requisitos a importar
    valid_stereotype=['RF','RFN','PV','AC','RA']
    while (reader.read)&&check_version
      case reader.node_type
        when Nokogiri::XML::Node::ELEMENT_NODE
          elem_name = reader.name.to_s
          case elem_name
          #<xmi:XMI xmi:version="2.1">
          #<XMI xmi.version="1.1" timestamp="2010-09-28 15:52:47">
          when 'xmi:XMI'
            current_version=reader.attribute('xmi:version')
            if current_version=='2.1'
              check_version=false
              return check_version
            end
          when 'XMI'
            current_version=reader.attribute('xmi.version')
            if current_version!='1.1'
              check_version=false
              return check_version
            end
          when 'UML:UseCase'
            current_requirement = RequirementXmi.new
            current_requirement.title = reader.attribute('name')
            current_requirement.id = reader.attribute('xmi.id')
          when 'UML:Actor'
            current_requirement = RequirementXmi.new
            current_requirement.title = reader.attribute('name')
            current_requirement.id = reader.attribute('xmi.id')
          when 'UML:Class'
            current_requirement = RequirementXmi.new
            current_requirement.title = reader.attribute('name')
            current_requirement.id = reader.attribute('xmi.id')
          when 'EAScenario'
            current_testcase = TestCaseXmi.new
            current_testcase.title = reader.attribute('name')
            current_testcase.note = reader.attribute('description')
            current_testcase.id = reader.attribute('subject')
            # todavia no esta claro si debe de crearse un tipo de tarea
            #@@requirements << current_testcase
          when 'UML:Stereotype'
            if current_requirement.type.nil?
              current_requirement.type= reader.attribute('name')
            end
          when 'UML:TaggedValue'
            if reader.attribute('tag')=="documentation"
              current_requirement.note= reader.attribute('value')
            end
            if reader.attribute('tag')=="author"
              current_requirement.author= reader.attribute('value')
            end
          end

        when Nokogiri::XML::Node::ELEMENT_DECL
          elem_name = reader.name.to_s
            case elem_name
            when 'UML:UseCase'
              @@requirements << current_requirement
            when 'UML:Actor'
              @@requirements << current_requirement
            when 'UML:Class'
              # si la clase no tiene estereotipo o es desconocido, no lo tenemos en cuenta
              if (current_requirement.type.nil? || valid_stereotype.include?(current_requirement.type))
                @@requirements << current_requirement
              end
            end
      end
    end
    return check_version
  rescue Nokogiri::XML::SyntaxError
    return false
  end

end
