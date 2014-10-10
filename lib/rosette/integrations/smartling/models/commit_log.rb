module Rosette
  module Integrations
    class Smartling
      class CommitLog < ActiveRecord::Base
        UNTRANSLATED = 'UNTRANSLATED'
        PENDING = 'PENDING'
        TRANSLATED = 'TRANSLATED'

        STATUSES = [UNTRANSLATED, PENDING, TRANSLATED]

        validates :commit_id, presence: true
        validates :status, inclusion: { in: STATUSES }

      end
    end
  end
end
