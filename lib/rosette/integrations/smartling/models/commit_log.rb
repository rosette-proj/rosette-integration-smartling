module Rosette
  module Integrations
    class Smartling
      class CommitLog < ActiveRecord::Base
        STATUSES = ['UNTRANSLATED', 'PENDING', 'TRANSLATED']

        validates :commit_id, presence: true
        validates :status, inclusion: { in: STATUSES }

      end
    end
  end
end
