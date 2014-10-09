# encoding: UTF-8

FactoryGirl.define do
  factory :commit_log, class: Rosette::Integrations::Smartling::CommitLog do
    sequence :commit_id, 'aaaa'
    sequence :status, 'UNTRANSLATED'
  end
end
