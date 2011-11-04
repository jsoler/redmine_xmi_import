require 'redmine'

Redmine::Plugin.register :redmine_requirements_importer do
  name 'Redmine Requirements Importer plugin'
  author 'Jaime Soler Gómez'
  description 'Import Requirements from XMI file'
  version '0.9.5'
  url 'http://www.emergya.es'
  author_url ''

  project_module :importer do
    permission :import, :importer => :index
  end
  menu :project_menu, :importer, { :controller => 'importer', :action => 'index' }, :caption => :label_import, :before => :settings, :param => :project_id


end
