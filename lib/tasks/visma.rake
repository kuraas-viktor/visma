namespace :visma do
  desc "Create all Visma models from config/visma_models.txt"
  task :generate do
    vismas = File.open('config/visma_models.txt').readlines

    # For each visma table name, create a Visma::model
    vismas.each do |vmodel|
      vmodel.strip!
      unless vmodel.include?("#") or vmodel.blank?
        doc = <<EOF
class Visma::#{vmodel} < ActiveRecord::Base
  establish_connection(:visma)
  self.table_name = VISMA_CONFIG["table_name_prefix"]
  self.table_name += "#{vmodel}"
  #self.primary_key = TODO
end
EOF

        path = "app/models/visma/#{vmodel.strip.underscore}.rb"
        File.open(path, 'w') {|f| f.write(doc) } unless File.exist?(path)
      end
    end
  end
end
