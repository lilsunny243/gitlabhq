# frozen_string_literal: true

FactoryBot.define do
  factory :ml_models, class: '::Ml::Model' do
    sequence(:name) { |n| "model#{n}" }

    project
    default_experiment { association :ml_experiments, project_id: project.id, name: name }

    trait :with_versions do
      versions { Array.new(2) { association(:ml_model_versions, model: instance) } }
    end

    trait :with_latest_version_and_package do
      transient do
        version { association(:ml_model_versions, :with_package, model: instance) }
      end
      versions { [version] }
      latest_version { version }
    end
  end
end
