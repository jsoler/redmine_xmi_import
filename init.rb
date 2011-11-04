require 'redmine'

Redmine::Plugin.register :redmine_xmi_import do
  name 'Redmine Requirements Importer plugin'
  author 'Jaime Soler Gómez'
  description 'Import Requirements from a XMI file'
  version '0.9.5'
  url 'http://www.emergya.es'

  project_module :xmi_import do
    permission :xmi_import, :xmi_import => :index
  end
  menu :project_menu, :xmi_import, { :controller => 'xmi_import', :action => 'index' }, :caption => :label_import, :before => :settings, :param => :project_id
end
