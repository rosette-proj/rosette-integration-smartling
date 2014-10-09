# encoding: UTF-8

require 'active_record/migration'

class SchemaManager

  class SchemaMigration < ActiveRecord::Base
    primary_key = :version
  end

  class << self

    def setup
      unless migrations_table_exists?
        create_migrations_table
      end
    end

    def migrate
      ActiveRecord::Migrator.migrate(migration_files_path)
    end

    def rollback
      ActiveRecord::Migrator.rollback(migration_files_path)
    end

    private

    def migration_files_path
      File.expand_path('../../migrations', __FILE__)
    end

    def connection
      ActiveRecord::Base.connection
    end

    def migrations_table_exists?
      connection.tables.include?('schema_migrations')
    end

    def create_migrations_table
      connection.create_table('schema_migrations') do |t|
        t.string(:version, length: 256)
      end

      connection.add_index(:schema_migrations, :version, unique: true)
    end
  end
end
