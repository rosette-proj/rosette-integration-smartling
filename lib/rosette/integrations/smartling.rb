# encoding: UTF-8
require 'active_record'
require 'rosette/integrations/smartling/models'

module Rosette
  module Integrations
    class Smartling

      def self.add_untranslated_commit(repo_name, commit_id)
        log = commit_log.where(repo_name: repo_name, commit_id: commit_id)
          .first_or_initialize

        if log.new_record?
          log.status = commit_log::UNTRANSLATED
          unless log.save
            raise 'Commit log not saved!'
          end
        else
          # some log error
        end
      end


      def self.commit_log
        CommitLog
      end

    end
  end
end
